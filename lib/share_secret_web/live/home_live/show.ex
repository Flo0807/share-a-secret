defmodule ShareSecretWeb.HomeLive.Show do
  use ShareSecretWeb, :live_view

  alias ShareSecret.Secrets

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    {:ok, assign_defaults(socket, params)}
  end

  @impl Phoenix.LiveView
  def handle_event("claim-encrypted-secret", %{"claim_key" => claim_key} = params, socket)
      when is_binary(claim_key) and map_size(params) == 1 do
    case socket.assigns do
      %{mode: :client, id: id} ->
        case Secrets.claim_encrypted_secret(id, claim_key) do
          {:ok, %{version: version, payload: payload}} ->
            {:reply, %{ok: true, version: version, payload: payload}, socket}

          {:error, :not_found} ->
            {:reply, %{ok: false, reason: "invalid_link"}, socket}
        end

      _invalid_mode ->
        {:reply, %{ok: false, reason: "invalid_link"}, socket}
    end
  end

  def handle_event("claim-encrypted-secret", _params, socket) do
    {:reply, %{ok: false, reason: "invalid_link"}, socket}
  end

  def handle_event("reveal-legacy-secret", _params, socket) do
    case socket.assigns do
      %{mode: :legacy, id: id, key: key} ->
        reveal_legacy(socket, id, key)

      _invalid_mode ->
        {:noreply, assign_invalid_link(socket)}
    end
  end

  defp reveal_legacy(socket, id, key) do
    try do
      case Secrets.reveal!(id, key) do
        {:ok, secret} ->
          {:noreply, socket |> assign(:error, nil) |> assign(:secret, secret)}

        {:error, :not_found} ->
          {:noreply, assign_invalid_link(socket)}
      end
    rescue
      _error ->
        {:noreply,
         assign(socket, :error, gettext("Error while decrypting the secret. Please try again."))}
    end
  end

  defp assign_defaults(socket, %{"id" => id, "key" => key}) do
    case Secrets.available_format(id) do
      1 -> assign_client_link(socket, id)
      0 -> assign_legacy_link(socket, id, key)
      nil -> assign_invalid_link(socket)
    end
  end

  defp assign_defaults(socket, %{"id" => id}) do
    case Secrets.available_format(id) do
      1 -> assign_client_link(socket, id)
      _legacy_or_missing -> assign_invalid_link(socket)
    end
  end

  defp assign_defaults(socket, _params), do: assign_invalid_link(socket)

  defp assign_client_link(socket, id) do
    socket
    |> assign(:error, nil)
    |> assign(:secret, nil)
    |> assign(:id, id)
    |> assign(:mode, :client)
  end

  defp assign_legacy_link(socket, id, key) do
    socket
    |> assign(:error, nil)
    |> assign(:secret, nil)
    |> assign(:id, id)
    |> assign(:key, key)
    |> assign(:mode, :legacy)
  end

  defp assign_invalid_link(socket) do
    socket
    |> assign(:mode, :invalid)
    |> assign(:secret, nil)
    |> assign(
      :error,
      gettext(
        "Invalid link. Check that you have entered the correct URL. This may also be an indication that the secret has already been revealed by someone else."
      )
    )
  end
end
