defmodule ShareSecret.Crypto do
  @moduledoc """
  The Crypto module.
  """

  @doc """
  Encrypts the given text with the given password with AES-128-CBC.
  """
  def encrypt(text, key) do
    iv = :crypto.strong_rand_bytes(16)
    secret_key = Base.decode16!(key)
    text = pad(text, 16)
    encrypted_text = :crypto.crypto_one_time(:aes_128_cbc, secret_key, iv, text, true)
    encrypted_text = iv <> encrypted_text
    :base64.encode(encrypted_text)
  end

  @doc """
  Decrypts the given encrypted text with the given key with AES-128-CBC.
  """
  def decrypt!(encrypted_text, key) do
    secret_key = Base.decode16!(key)
    encrypted_text = :base64.decode(encrypted_text)
    <<iv::binary-16, encrypted_text::binary>> = encrypted_text
    decrypted_text = :crypto.crypto_one_time(:aes_128_cbc, secret_key, iv, encrypted_text, false)
    unpad(decrypted_text)
  end

  @doc """
  Unpads the given data.
  """
  def unpad(data) do
    to_remove = :binary.last(data)
    :binary.part(data, 0, byte_size(data) - to_remove)
  end

  @doc """
  Pads the given data.
  """
  def pad(data, block_size) do
    to_add = block_size - rem(byte_size(data), block_size)
    data <> :binary.copy(<<to_add>>, to_add)
  end

  @doc """
  Generates a random key.
  """
  def generate_key(length \\ 32) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode16()
    |> binary_part(0, length)
  end
end
