defmodule ShareSecret.CryptoBehaviour do
  @moduledoc """
  The behaviour for the crypto implementation.
  """
  @callback encrypt(binary(), binary()) :: binary()
  @callback decrypt!(binary(), binary()) :: binary()
  @callback generate_key() :: binary()
  @callback generate_key(integer()) :: binary()
end
