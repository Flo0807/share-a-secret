defmodule ShareSecret.ExpirationWorker do
  @moduledoc """
  A simple gen server that checks for expired secrets and deletes them.
  """

  use GenServer
  alias ShareSecret.Secrets

  @interval 5_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl GenServer
  def init(state) do
    schedule_work()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:check_expiration, state) do
    Secrets.delete_expired_secrets()

    schedule_work()

    {:noreply, state}
  end

  defp schedule_work() do
    Process.send_after(self(), :check_expiration, @interval)
  end
end
