defmodule ShareSecretWeb.HomeLive.Show do
  use ShareSecretWeb, :live_view

  alias ShareSecret.Secrets

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    socket =
      socket
      |> assign_defaults(params)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("reveal-secret", _params, socket) do
    %{assigns: %{id: id, key: key}} = socket

    socket =
      try do
        {:ok, secret} = Secrets.reveal!(id, key)

        socket
        |> assign(:error, nil)
        |> assign(:secret, secret)
      rescue
        _error ->
          socket
          |> assign(
            :error,
            gettext("Error while decrypting the secret. Please try again.")
          )
      end

    {:noreply, socket}
  end

  defp assign_defaults(socket, %{"id" => id, "key" => key}) do
    if ShareSecret.Secrets.exists?(id) do
      socket
      |> assign(:error, nil)
      |> assign(:secret, nil)
      |> assign(:id, id)
      |> assign(:key, key)
    else
      assign_invalid_link(socket)
    end
  end

  defp assign_defaults(socket, _params), do: assign_invalid_link(socket)

  defp assign_invalid_link(socket) do
    socket
    |> assign(
      :error,
      gettext(
        "Invalid link. Check that you have entered the correct URL. This may also be an indication that the secret has already been revealed by someone else."
      )
    )
  end
end
