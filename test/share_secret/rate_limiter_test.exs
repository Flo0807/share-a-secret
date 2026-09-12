defmodule ShareSecret.RateLimiterTest do
  use ExUnit.Case, async: true

  alias ShareSecret.RateLimiter

  test "limits the number of created secrets per client window" do
    client_key = :crypto.strong_rand_bytes(32)

    for _attempt <- 1..5 do
      assert RateLimiter.allow?(client_key, 10)
    end

    refute RateLimiter.allow?(client_key, 1)
  end
end
