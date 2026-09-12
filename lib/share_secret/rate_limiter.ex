defmodule ShareSecret.RateLimiter do
  @moduledoc false

  use GenServer

  @window_ms 60_000
  @secret_limit 50
  @maximum_clients 100_000

  def start_link(_options) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def allow?(client_key, secret_count)
      when is_binary(client_key) and is_integer(secret_count) and secret_count > 0 do
    GenServer.call(__MODULE__, {:allow, client_key, secret_count})
  end

  @impl GenServer
  def init(state) do
    schedule_cleanup()
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:allow, client_key, secret_count}, _from, state) do
    now = System.monotonic_time(:millisecond)
    {window_started, used} = current_window(Map.get(state, client_key), now)
    new_client? = not Map.has_key?(state, client_key)

    allowed? =
      used + secret_count <= @secret_limit and
        (not new_client? or map_size(state) < @maximum_clients)

    state =
      if allowed? do
        Map.put(state, client_key, {window_started, used + secret_count})
      else
        state
      end

    {:reply, allowed?, state}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    cutoff = System.monotonic_time(:millisecond) - @window_ms
    state = Map.reject(state, fn {_key, {window_started, _used}} -> window_started <= cutoff end)
    schedule_cleanup()
    {:noreply, state}
  end

  defp current_window({window_started, used}, now) when now - window_started < @window_ms do
    {window_started, used}
  end

  defp current_window(_expired_or_missing, now), do: {now, 0}

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, @window_ms)
end
