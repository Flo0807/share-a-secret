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
      expired = insert(:secret, expires_at: DateTime.add(now(), -3600))
      not_expired = insert(:secret, expires_at: DateTime.add(now(), 3600))

      Secrets.delete_expired_secrets()

      assert Repo.get(Secret, expired.id) == nil
      assert Repo.get(Secret, not_expired.id) != nil
    end
  end

  defp insert(:secret, attrs \\ %{}) do
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

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
