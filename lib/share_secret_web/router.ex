defmodule ShareSecretWeb.Router do
  use ShareSecretWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShareSecretWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", ShareSecretWeb do
    pipe_through :browser

    live "/", HomeLive.Index, :index
    live "/:id", HomeLive.Show, :show
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:share_secret, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShareSecretWeb.Telemetry
    end
  end
end
