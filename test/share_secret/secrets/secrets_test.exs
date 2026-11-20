defmodule ShareSecret.SecretsTest do
  @moduledoc """
  Provides tests for the Secrets context.
  """
  use ShareSecret.DataCase

  import Mox

  alias ShareSecret.Secrets
  alias ShareSecret.Secrets.Secret

  setup :verify_on_exit!

  describe "get_secret/1" do
    test "returns the secret when it exists" do
      secret = insert(:secret)
      assert Secrets.get_secret(secret.id) == secret
    end

    test "returns nil when the secret doesn't exist" do
      assert Secrets.get_secret(Ecto.UUID.generate()) == nil
    end

    test "returns nil for invalid UUID" do
      assert Secrets.get_secret("not-a-uuid") == nil
    end
  end

  describe "exists?/1" do
    test "returns true when the secret exists" do
      secret = insert(:secret)
      assert Secrets.exists?(secret.id)
    end

    test "returns false when the secret doesn't exist" do
      refute Secrets.exists?(Ecto.UUID.generate())
    end

    test "returns false when the secret is expired or the id is invalid" do
      secret =
        insert(:secret,
          inserted_at: NaiveDateTime.add(naive_now(), -7200),
          expires_at: DateTime.add(now(), -3600)
        )

      refute Secrets.exists?(secret.id)
      refute Secrets.exists?("not-a-uuid")
    end
  end

  describe "reveal!/2" do
    test "reveals and deletes the secret when it exists" do
      secret = insert(:secret, secret: "encrypted_secret")

      expect(ShareSecret.CryptoMock, :decrypt!, fn "encrypted_secret", "key" ->
        "decrypted_secret"
      end)

      assert {:ok, "decrypted_secret"} = Secrets.reveal!(secret.id, "key")
      assert Repo.get(Secret, secret.id) == nil
    end

    test "returns error when the secret doesn't exist" do
      assert {:error, :not_found} = Secrets.reveal!(Ecto.UUID.generate(), "key")
    end

    test "does not consume a legacy secret when decryption fails" do
      secret = insert(:secret, secret: "encrypted_secret")

      expect(ShareSecret.CryptoMock, :decrypt!, fn "encrypted_secret", "wrong-key" ->
        raise "invalid key"
      end)

      assert_raise RuntimeError, "invalid key", fn -> Secrets.reveal!(secret.id, "wrong-key") end
      assert Repo.get(Secret, secret.id)
    end

    test "does not reveal expired or client-encrypted secrets" do
      expired =
        insert(:secret,
          inserted_at: NaiveDateTime.add(naive_now(), -7200),
          expires_at: DateTime.add(now(), -3600)
        )

      entry = encrypted_entry()
      assert {:ok, [id]} = Secrets.create_encrypted_secrets([entry], 3600)

      assert {:error, :not_found} = Secrets.reveal!(expired.id, "key")
      assert {:error, :not_found} = Secrets.reveal!(id, "key")
    end
  end

  describe "create_encrypted_secrets/2" do
    test "stores only an opaque v1 envelope and verifier" do
      entry = encrypted_entry()

      assert {:ok, [id]} = Secrets.create_encrypted_secrets([entry], 3600)

      stored = Repo.get!(Secret, id)
      assert stored.format_version == 1
      assert stored.secret == nil
      assert stored.encrypted_payload == decode!(entry.payload)
      assert stored.claim_verifier == decode!(entry.claim_verifier)
      assert DateTime.diff(stored.expires_at, now()) in 3599..3600
    end

    test "creates a maximum-sized batch atomically and preserves order" do
      entries = for _ <- 1..10, do: encrypted_entry()

      assert {:ok, ids} = Secrets.create_encrypted_secrets(entries, 3600)
      assert ids == Enum.map(entries, & &1.id)
      assert Repo.aggregate(Secret, :count) == 10
    end

    test "rejects unsupported counts and expiration values" do
      assert {:error, :invalid} = Secrets.create_encrypted_secrets([], 3600)

      assert {:error, :invalid} =
               Secrets.create_encrypted_secrets(List.duplicate(encrypted_entry(), 11), 3600)

      assert {:error, :invalid} = Secrets.create_encrypted_secrets([encrypted_entry()], 1234)
      assert Repo.aggregate(Secret, :count) == 0
    end

    test "rejects malformed IDs, envelopes, verifiers, and duplicate IDs without partial writes" do
      valid = encrypted_entry()

      invalid_entries = [
        %{valid | id: String.upcase(valid.id)},
        %{valid | payload: Base.url_encode64(<<2, 0::232>>, padding: false)},
        %{valid | payload: Base.url_encode64(<<1, 0::224>>, padding: false)},
        %{valid | payload: valid.payload <> "="},
        %{valid | claim_verifier: Base.url_encode64(<<0::248>>, padding: false)}
      ]

      for invalid <- invalid_entries do
        assert {:error, :invalid} =
                 Secrets.create_encrypted_secrets([encrypted_entry(), invalid], 3600)
      end

      assert {:error, :invalid} = Secrets.create_encrypted_secrets([valid, valid], 3600)
      assert Repo.aggregate(Secret, :count) == 0
    end

    test "rolls back the whole batch when an id already exists" do
      existing = encrypted_entry()
      assert {:ok, [_]} = Secrets.create_encrypted_secrets([existing], 3600)

      assert {:error, :invalid} =
               Secrets.create_encrypted_secrets(
                 [encrypted_entry(), encrypted_entry(id: existing.id)],
                 3600
               )

      assert Repo.aggregate(Secret, :count) == 1
    end
  end

  describe "claim_encrypted_secret/2" do
    test "returns the opaque envelope and atomically consumes the secret" do
      claim_key = :crypto.strong_rand_bytes(32)
      entry = encrypted_entry(claim_key: claim_key)
      assert {:ok, [id]} = Secrets.create_encrypted_secrets([entry], 3600)

      assert {:ok, %{version: 1, payload: entry.payload}} ==
               Secrets.claim_encrypted_secret(id, encode(claim_key))

      assert Repo.get(Secret, id) == nil
      assert {:error, :not_found} = Secrets.claim_encrypted_secret(id, encode(claim_key))
    end

    test "allows exactly one of two concurrent claimants to consume the secret" do
      claim_key = :crypto.strong_rand_bytes(32)
      entry = encrypted_entry(claim_key: claim_key)
      assert {:ok, [id]} = Secrets.create_encrypted_secrets([entry], 3600)

      claimants =
        for _index <- 1..2 do
          Task.async(fn ->
            receive do
              :claim -> Secrets.claim_encrypted_secret(id, encode(claim_key))
            end
          end)
        end

      Enum.each(claimants, &send(&1.pid, :claim))
      results = Enum.map(claimants, &Task.await/1)

      assert Enum.count(results, &match?({:ok, _claimed}, &1)) == 1
      assert Enum.count(results, &match?({:error, :not_found}, &1)) == 1
    end

    test "wrong or malformed claims do not consume the secret" do
      claim_key = :crypto.strong_rand_bytes(32)
      entry = encrypted_entry(claim_key: claim_key)
      assert {:ok, [id]} = Secrets.create_encrypted_secrets([entry], 3600)

      assert {:error, :not_found} =
               Secrets.claim_encrypted_secret(id, encode(:crypto.strong_rand_bytes(32)))

      assert {:error, :not_found} =
               Secrets.claim_encrypted_secret(id, entry.claim_verifier <> "=")

      assert Repo.get(Secret, id)
    end

    test "does not claim expired, legacy, or invalid IDs" do
      claim_key = :crypto.strong_rand_bytes(32)
      verifier = :crypto.hash(:sha256, claim_key)

      expired =
        insert(:encrypted_secret,
          claim_verifier: verifier,
          inserted_at: NaiveDateTime.add(naive_now(), -7200),
          expires_at: DateTime.add(now(), -3600)
        )

      legacy = insert(:secret)

      assert {:error, :not_found} = Secrets.claim_encrypted_secret(expired.id, encode(claim_key))
      assert {:error, :not_found} = Secrets.claim_encrypted_secret(legacy.id, encode(claim_key))

      assert {:error, :not_found} =
               Secrets.claim_encrypted_secret("not-a-uuid", encode(claim_key))

      assert Repo.get(Secret, expired.id)
      assert Repo.get(Secret, legacy.id)
    end
  end

  describe "create_secrets/3" do
    test "creates the specified number of secrets" do
      expect(ShareSecret.CryptoMock, :generate_key, 2, fn -> "generated_key" end)

      expect(ShareSecret.CryptoMock, :encrypt, 2, fn "secret", "generated_key" ->
        "encrypted_secret"
      end)

      assert {:ok, links} = Secrets.create_secrets("secret", 2, 3600)
      assert length(links) == 2

      for %{id: id, key: key} <- links do
        assert Repo.get(Secret, id)
        assert key == "generated_key"
      end
    end

    test "sets correct expiration time" do
      expect(ShareSecret.CryptoMock, :generate_key, fn -> "key" end)
      expect(ShareSecret.CryptoMock, :encrypt, fn _, _ -> "encrypted" end)

      {:ok, [%{id: id}]} = Secrets.create_secrets("secret", 1, 3600)
      secret = Repo.get(Secret, id)

      assert DateTime.diff(secret.expires_at, now()) in 3599..3600
    end
  end

  describe "delete_expired_secrets/0" do
    test "deletes only expired secrets" do
      expired =
        insert(:secret,
          inserted_at: NaiveDateTime.add(naive_now(), -7200),
          expires_at: DateTime.add(now(), -3600)
        )

      not_expired = insert(:secret, expires_at: DateTime.add(now(), 3600))

      Secrets.delete_expired_secrets()

      assert Repo.get(Secret, expired.id) == nil
      assert Repo.get(Secret, not_expired.id) != nil
    end
  end

  defp insert(kind, attrs \\ %{})

  defp insert(:secret, attrs) do
    {:ok, secret} =
      attrs
      |> Enum.into(%{
        secret: "some encrypted secret",
        expires_at: DateTime.add(now(), 3600)
      })
      |> then(&struct(Secret, &1))
      |> Repo.insert()

    secret
  end

  defp insert(:encrypted_secret, attrs) do
    {:ok, secret} =
      attrs
      |> Enum.into(%{
        format_version: 1,
        secret: nil,
        encrypted_payload: <<1, 0::232>>,
        claim_verifier: :crypto.strong_rand_bytes(32),
        expires_at: DateTime.add(now(), 3600)
      })
      |> then(&struct(Secret, &1))
      |> Repo.insert()

    secret
  end

  defp encrypted_entry(overrides \\ []) do
    claim_key = Keyword.get(overrides, :claim_key, :crypto.strong_rand_bytes(32))

    defaults = %{
      id: Ecto.UUID.generate(),
      payload: encode(<<1, :crypto.strong_rand_bytes(29)::binary>>),
      claim_verifier: encode(:crypto.hash(:sha256, claim_key))
    }

    overrides
    |> Keyword.drop([:claim_key])
    |> Enum.into(defaults)
  end

  defp encode(value), do: Base.url_encode64(value, padding: false)
  defp decode!(value), do: Base.url_decode64!(value, padding: false)

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp naive_now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
end
