defmodule ShareSecretWeb.HomeLive.Index do
  use ShareSecretWeb, :live_view

  alias ShareSecret.Secrets
  alias ShareSecret.RateLimiter

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
     |> assign(:rate_limit_key, rate_limit_key(socket))
     |> assign(:form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "create-encrypted-secrets",
        %{"entries" => entries, "expiration" => expiration} = params,
        socket
      )
      when is_list(entries) and is_integer(expiration) and map_size(params) == 2 do
    with true <- RateLimiter.allow?(socket.assigns.rate_limit_key, rate_limit_cost(entries)),
         true <- Enum.all?(entries, &valid_entry?/1),
         {:ok, _ids} <- Secrets.create_encrypted_secrets(entries, expiration) do
      {:reply, %{ok: true}, socket}
    else
      _rate_limited_or_invalid ->
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

  defp rate_limit_cost(entries), do: entries |> length() |> max(1) |> min(@max_links)

  defp rate_limit_key(socket) do
    identity = trusted_forwarded_for(socket) || peer_address(socket) || "unknown"
    :crypto.hash(:sha256, :erlang.term_to_binary(identity))
  end

  defp trusted_forwarded_for(socket) do
    if Application.get_env(:share_secret, :trust_proxy_headers, false) do
      socket
      |> get_connect_info(:x_headers)
      |> List.wrap()
      |> Enum.find_value(fn
        {"x-forwarded-for", value} ->
          value |> String.split(",", parts: 2) |> hd() |> String.trim()

        _header ->
          nil
      end)
    end
  end

  defp peer_address(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} -> address
      _missing -> nil
    end
  end
end
