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
    changeset = change()

    socket =
      socket
      |> assign(:max_links, @max_links)
      |> assign(:expiration_options, @expiration_options)
      |> assign(:expiration_default, @expiration_default)
      |> assign(:error, nil)
      |> assign(:loading, false)
      |> assign(:links, [])
      |> assign_form(changeset)

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
  def handle_event("validate", %{"create_links_form" => params}, socket) do
    changeset = params |> change() |> Map.put(:action, :validate)
    socket = assign_form(socket, changeset)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("submit", %{"create_links_form" => params}, socket) do
    result = params |> change() |> Ecto.Changeset.apply_action(:validate)

    socket =
      case result do
        {:ok, opts} ->
          send(self(), {:generate_links, opts})

          socket
          |> assign(:error, nil)
          |> assign(:loading, true)

        {:error, changeset} ->
          socket
          |> assign(:error, gettext("Invalid form data."))
          |> assign_form(changeset)
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:generate_links, opts}, socket) do
    %{secret: secret, link_count: link_count, expiration: expiration} = opts

    socket =
      case Secrets.create_secrets(secret, link_count, expiration) do
        {:ok, secrets} ->
          assign_links(socket, secrets, socket.assigns.link_url)

        :error ->
          assign(socket, :error, gettext("Failed to create links."))
      end
      |> assign(:loading, false)

    {:noreply, socket}
  end

  defp change(attrs \\ %{}) do
    fields = %{
      secret: :string,
      link_count: :integer,
      expiration: :integer
    }

    default_params = %{
      expiration: @expiration_default,
      link_count: 1
    }

    {default_params, fields}
    |> Ecto.Changeset.cast(attrs, Map.keys(fields))
    |> Ecto.Changeset.validate_required([:secret, :link_count, :expiration])
    |> Ecto.Changeset.validate_number(:link_count,
      greater_than: 0,
      less_than_or_equal_to: @max_links
    )
    |> Ecto.Changeset.validate_inclusion(
      :expiration,
      Enum.map(@expiration_options, fn {_label, value} -> value end)
    )
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :create_links_form))
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
end
