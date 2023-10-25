defmodule ShareSecretWeb.InitAssigns do
  @moduledoc """
  This module is used to initialize assigns for all LiveViews.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    socket =
      attach_hook(socket, :current_url, :handle_params, fn
        _params, url, socket ->
          {:cont, assign(socket, :current_url, url)}
      end)

    {:cont, socket}
  end
end
