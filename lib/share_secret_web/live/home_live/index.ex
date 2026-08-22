defmodule ShareSecretWeb.HomeLive.Index do
  use ShareSecretWeb, :live_view

  alias ShareSecret.Secrets

  @max_links 10
  @expiration_options [
    {ngettext("%{count} minute", "%{count} minutes", 10), 60 * 10},
    {ngettext("%{count} hour", "%{count} hours", 1), 60 * 60},
    {ngettext("%{count} hour", "%{count} hours", 12), 60 * 60 * 12},
    {ngettext("%{count} day", "%{count} days", 2), 60 * 60 * 24 * 2},
    {ngettext("%{count} week", "%{count} weeks", 1), 60 * 60 * 24 * 7},
    {ngettext("%{count} week", "%{count} weeks", 2), 60 * 60 * 24 * 14}
  ]
  @expiration_default 60 * 60 * 24 * 2

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    form =
      %{
        "secret" => "",
        "link_count" => "1",
        "expiration" => Integer.to_string(@expiration_default)
      }
      |> to_form(as: :create_links_form)

    {:ok,
     socket
     |> assign(:max_links, @max_links)
     |> assign(:expiration_options, @expiration_options)
     |> assign(:expiration_default, @expiration_default)
     |> assign(:form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "create-encrypted-secrets",
        %{"entries" => entries, "expiration" => expiration} = params,
        socket
      )
      when is_list(entries) and is_integer(expiration) and map_size(params) == 2 do
    if Enum.all?(entries, &valid_entry?/1) do
      case Secrets.create_encrypted_secrets(entries, expiration) do
        {:ok, _ids} -> {:reply, %{ok: true}, socket}
        {:error, :invalid} -> {:reply, %{ok: false, reason: "invalid_request"}, socket}
      end
    else
      {:reply, %{ok: false, reason: "invalid_request"}, socket}
    end
  end

  def handle_event("create-encrypted-secrets", _params, socket) do
    {:reply, %{ok: false, reason: "invalid_request"}, socket}
  end

  defp valid_entry?(entry) when is_map(entry) do
    Map.keys(entry) |> Enum.sort() == ["claim_verifier", "id", "payload"]
  end

  defp valid_entry?(_entry), do: false
end
