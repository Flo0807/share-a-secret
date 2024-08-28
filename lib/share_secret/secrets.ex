defmodule ShareSecret.Secrets do
  @moduledoc """
  The Secrets context.
  """

  import Ecto.Query, warn: false
  alias ShareSecret.Repo

  alias ShareSecret.Secrets.Secret

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
  def exists?(id), do: get_secret(id) != nil

  @doc """
  Reveals a secret.
  """
  def reveal!(id, key) do
    case get_secret(id) do
      %{secret: secret} = item ->
        encrypted_secret = crypto_impl().decrypt!(secret, key)

        item
        |> Repo.delete!()

        {:ok, encrypted_secret}

      _not_found ->
        {:error, :not_found}
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
    |> where([s], s.expires_at < ^DateTime.utc_now())
    |> Repo.delete_all()
  end

  defp add_seconds_to_datetime(seconds) do
    DateTime.utc_now()
    |> DateTime.add(seconds, :second)
    |> DateTime.truncate(:second)
  end

  defp uuid?(id) do
    match?({:ok, _}, Ecto.UUID.dump(id))
  end
end
