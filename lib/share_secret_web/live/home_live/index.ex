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
    form = to_form(%{"secret" => "", "expiration" => @expiration_default, "link_count" => 1})

    socket =
      socket
      |> assign(:max_links, @max_links)
      |> assign(:expiration_options, @expiration_options)
      |> assign(:expiration_default, @expiration_default)
      |> assign(:error, nil)
      |> assign(:loading, false)
      |> assign(:links, [])
      |> assign(:form, form)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, uri, socket) do
    %{scheme: scheme, authority: authority} = URI.parse(uri)

    link_url = "#{scheme}://#{authority}/:id?key=:key"
    socket = assign(socket, :link_url, link_url)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("submit", params, socket) do
    %{"expiration" => expiration, "link_count" => link_count, "secret" => secret} = params

    expiration = expiration |> String.to_integer()
    link_count = link_count |> String.to_integer()

    socket =
      case valid?(expiration, link_count, secret) do
        true ->
          send(self(), {:generate_links, expiration, link_count, secret})

          socket
          |> assign(:error, nil)
          |> assign(:loading, true)

        false ->
          socket
          |> assign(:error, gettext("Invalid form data."))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:generate_links, expiration, link_count, secret}, socket) do
    socket =
      case Secrets.create_secrets(secret, link_count, expiration) do
        {:ok, secrets} ->
          socket
          |> assign_links(secrets, socket.assigns.link_url)

        :error ->
          socket
          |> assign(:error, gettext("Failed to create links."))
      end
      |> assign(:loading, false)

    {:noreply, socket}
  end

  defp assign_links(socket, secrets, link_url) do
    links =
      for %{id: id, key: key} <- secrets do
        link_url
        |> String.replace(":id", id)
        |> String.replace(":key", key)
      end

    assign(socket, :links, links)
  end

  defp valid?(expiration, link_count, secret) do
    valid_expirations = Enum.map(@expiration_options, fn {_label, value} -> value end)

    Enum.member?(valid_expirations, expiration) and link_count > 0 and link_count <= @max_links and
      secret != "" and byte_size(secret) <= 100_000
  end
end
