defmodule ShareSecret.CryptoTest do
  @doc """
  Provides tests for the Crypto module.
  """
  use ExUnit.Case

  alias ShareSecret.Crypto

  describe "encrypt/2 and decrypt!/2" do
    test "encrypts and decrypts text correctly" do
      text = "Hello, World!"
      key = Crypto.generate_key()

      encrypted = Crypto.encrypt(text, key)
      decrypted = Crypto.decrypt!(encrypted, key)

      assert decrypted == text
    end

    test "different keys produce different ciphertexts" do
      text = "Same text, different keys"
      key1 = Crypto.generate_key()
      key2 = Crypto.generate_key()

      encrypted1 = Crypto.encrypt(text, key1)
      encrypted2 = Crypto.encrypt(text, key2)

      assert encrypted1 != encrypted2
    end

    test "same text and key produce different ciphertexts due to IV" do
      text = "Same text, same key"
      key = Crypto.generate_key()

      encrypted1 = Crypto.encrypt(text, key)
      encrypted2 = Crypto.encrypt(text, key)

      assert encrypted1 != encrypted2
    end

    test "decryption fails with wrong key" do
      text = "Secret message"
      correct_key = Crypto.generate_key()
      wrong_key = Crypto.generate_key()

      encrypted = Crypto.encrypt(text, correct_key)

      assert_raise ArgumentError, fn ->
        Crypto.decrypt!(encrypted, wrong_key)
      end
    end
  end

  describe "pad/2 and unpad/1" do
    test "pad adds correct padding" do
      data = "test"
      padded = Crypto.pad(data, 16)
      assert byte_size(padded) == 16
      assert String.ends_with?(padded, <<12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12>>)
    end

    test "unpad removes correct padding" do
      padded = "test" <> <<12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12>>
      unpadded = Crypto.unpad(padded)
      assert unpadded == "test"
    end

    test "pad and unpad are inverse operations" do
      data = "Hello, Crypto!"
      padded = Crypto.pad(data, 16)
      unpadded = Crypto.unpad(padded)
      assert unpadded == data
    end
  end

  describe "generate_key/1" do
    test "generates key of correct length" do
      key = Crypto.generate_key()
      assert byte_size(key) == 32
    end

    test "generates different keys" do
      key1 = Crypto.generate_key()
      key2 = Crypto.generate_key()
      assert key1 != key2
    end

    test "generates key of specified length" do
      key = Crypto.generate_key(16)
      assert byte_size(key) == 16
    end
  end
end
