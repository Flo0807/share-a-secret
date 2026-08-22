defmodule ShareSecret.Secrets do
  @moduledoc """
  The Secrets context.
  """

  import Ecto.Query, warn: false
  alias ShareSecret.Repo

  alias ShareSecret.Secrets.Secret

  @max_links 10
  @minimum_envelope_bytes 30
  @maximum_envelope_bytes 65_565
  @maximum_encoded_envelope_bytes 87_420
  @base64url_regex ~r/\A[A-Za-z0-9_-]+\z/
  @allowed_expirations [
    60 * 10,
    60 * 60,
    60 * 60 * 12,
    60 * 60 * 24 * 2,
    60 * 60 * 24 * 7,
    60 * 60 * 24 * 14
  ]

  @doc """
  Returns the crypto implementation.
  """
  def crypto_impl do
    Application.get_env(:share_secret, :crypto, ShareSecret.Crypto)
  end

  @doc """
  Gets a single secret by id.
  """
  def get_secret(id) do
    if uuid?(id), do: Repo.get(Secret, id), else: nil
  end

  @doc """
  Checks if a secret exists.
  """
  def exists?(id) do
    if uuid?(id) do
      Secret
      |> where(
        [secret],
        secret.id == ^id and
          secret.expires_at > fragment("timezone('UTC', CURRENT_TIMESTAMP)")
      )
      |> Repo.exists?()
    else
      false
    end
  end

  @doc """
  Reveals a secret.
  """
  def reveal!(id, key) do
    if uuid?(id) do
      Repo.transaction(fn ->
        query =
          from secret in Secret,
            where:
              secret.id == ^id and secret.format_version == 0 and
                secret.expires_at > fragment("timezone('UTC', CURRENT_TIMESTAMP)"),
            lock: "FOR UPDATE"

        case Repo.one(query) do
          %{secret: encrypted_secret} = item ->
            plaintext = crypto_impl().decrypt!(encrypted_secret, key)
            Repo.delete!(item)
            {:ok, plaintext}

          nil ->
            {:error, :not_found}
        end
      end)
      |> case do
        {:ok, result} -> result
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Stores already-encrypted v1 payloads without receiving plaintext or decryption keys.
  """
  def create_encrypted_secrets(entries, expiration)
      when is_list(entries) and is_integer(expiration) do
    with :ok <- validate_entry_count(entries),
         :ok <- validate_expiration(expiration),
         {:ok, changesets} <- encrypted_changesets(entries, expiration),
         :ok <- validate_unique_ids(changesets) do
      multi =
        changesets
        |> Enum.with_index()
        |> Enum.reduce(Ecto.Multi.new(), fn {changeset, index}, multi ->
          Ecto.Multi.insert(multi, {:secret, index}, changeset)
        end)

      case Repo.transaction(multi) do
        {:ok, results} ->
          ids =
            for index <- 0..(length(changesets) - 1) do
              results |> Map.fetch!({:secret, index}) |> Map.fetch!(:id)
            end

          {:ok, ids}

        {:error, _operation, _reason, _changes} ->
          {:error, :invalid}
      end
    end
  end

  def create_encrypted_secrets(_entries, _expiration), do: {:error, :invalid}

  @doc """
  Atomically consumes a v1 secret when presented with its independent claim capability.
  """
  def claim_encrypted_secret(id, encoded_claim_key) do
    with true <- uuid?(id),
         {:ok, claim_key} <- decode_canonical(encoded_claim_key, 32) do
      claim_verifier = :crypto.hash(:sha256, claim_key)

      query =
        from secret in Secret,
          where:
            secret.id == ^id and secret.format_version == 1 and
              secret.claim_verifier == ^claim_verifier and
              secret.expires_at > fragment("timezone('UTC', CURRENT_TIMESTAMP)"),
          select: %{
            format_version: secret.format_version,
            encrypted_payload: secret.encrypted_payload
          }

      case Repo.delete_all(query) do
        {1, [claimed]} ->
          {:ok,
           %{
             version: claimed.format_version,
             payload: Base.url_encode64(claimed.encrypted_payload, padding: false)
           }}

        _not_found ->
          {:error, :not_found}
      end
    else
      _invalid -> {:error, :not_found}
    end
  end

  @doc """
  Creates secrets.
  """
  def create_secrets(secret, link_count, expiration) do
    links =
      for _ <- 1..link_count do
        id = Ecto.UUID.generate()
        key = crypto_impl().generate_key()
        secret_encrypted = crypto_impl().encrypt(secret, key)
        expires_at = add_seconds_to_datetime(expiration)

        schema = %Secret{id: id, secret: secret_encrypted, expires_at: expires_at}

        %{id: id, key: key, schema: schema}
      end

    result =
      Repo.transaction(fn ->
        for %{schema: schema} <- links do
          schema
          |> Repo.insert!()
        end
      end)

    case result do
      {:ok, _list} ->
        links =
          links
          |> Enum.map(fn %{id: id, key: key} ->
            %{id: id, key: key}
          end)

        {:ok, links}

      _error ->
        :error
    end
  end

  @doc """
  Deletes expired secrets.
  """
  def delete_expired_secrets do
    Secret
    |> where([secret], secret.expires_at <= fragment("timezone('UTC', CURRENT_TIMESTAMP)"))
    |> Repo.delete_all()
  end

  defp add_seconds_to_datetime(seconds) do
    now()
    |> DateTime.add(seconds, :second)
  end

  defp encrypted_changesets(entries, expiration) do
    expires_at = add_seconds_to_datetime(expiration)

    entries
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, changesets} ->
      with {:ok, id} <- entry |> fetch_value("id", :id) |> cast_uuid(),
           {:ok, payload} <- entry |> fetch_value("payload", :payload) |> decode_envelope(),
           {:ok, claim_verifier} <-
             entry |> fetch_value("claim_verifier", :claim_verifier) |> decode_canonical(32) do
        secret = %Secret{id: id, format_version: 1, expires_at: expires_at}

        changeset =
          Secret.encrypted_changeset(secret, %{
            encrypted_payload: payload,
            claim_verifier: claim_verifier
          })

        if changeset.valid? do
          {:cont, {:ok, [changeset | changesets]}}
        else
          {:halt, {:error, :invalid}}
        end
      else
        _invalid -> {:halt, {:error, :invalid}}
      end
    end)
    |> case do
      {:ok, changesets} -> {:ok, Enum.reverse(changesets)}
      error -> error
    end
  end

  defp decode_envelope(value) do
    with true <- is_binary(value) and byte_size(value) <= @maximum_encoded_envelope_bytes,
         {:ok, payload} <- decode_canonical(value),
         true <- byte_size(payload) in @minimum_envelope_bytes..@maximum_envelope_bytes,
         <<1, _rest::binary>> <- payload do
      {:ok, payload}
    else
      _invalid -> :error
    end
  end

  defp decode_canonical(value, expected_size \\ nil)

  defp decode_canonical(value, expected_size) when is_binary(value) do
    expected_encoded_size = if expected_size, do: encoded_size(expected_size), else: nil

    with true <- is_nil(expected_encoded_size) or byte_size(value) == expected_encoded_size,
         true <- Regex.match?(@base64url_regex, value),
         {:ok, decoded} <- Base.url_decode64(value, padding: false),
         true <- Base.url_encode64(decoded, padding: false) == value,
         true <- is_nil(expected_size) or byte_size(decoded) == expected_size do
      {:ok, decoded}
    else
      _invalid -> :error
    end
  end

  defp decode_canonical(_value, _expected_size), do: :error

  defp encoded_size(byte_count), do: div(byte_count * 8 + 5, 6)

  defp fetch_value(map, string_key, atom_key) when is_map(map) do
    case Map.fetch(map, string_key) do
      {:ok, value} -> value
      :error -> Map.get(map, atom_key)
    end
  end

  defp validate_entry_count(entries) do
    if length(entries) in 1..@max_links, do: :ok, else: {:error, :invalid}
  end

  defp validate_expiration(expiration) do
    if expiration in @allowed_expirations, do: :ok, else: {:error, :invalid}
  end

  defp validate_unique_ids(changesets) do
    ids = Enum.map(changesets, &Ecto.Changeset.get_field(&1, :id))
    if Enum.uniq(ids) == ids, do: :ok, else: {:error, :invalid}
  end

  defp cast_uuid(id) when is_binary(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         true <- uuid == id do
      {:ok, uuid}
    else
      _invalid -> :error
    end
  end

  defp cast_uuid(_id), do: :error

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp uuid?(id) do
    match?({:ok, _}, Ecto.UUID.dump(id))
  end
end
