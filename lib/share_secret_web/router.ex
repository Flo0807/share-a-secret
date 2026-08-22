defmodule ShareSecretWeb.Router do
  use ShareSecretWeb, :router

  @security_headers %{
    "cache-control" => "no-store",
    "content-security-policy" =>
      "default-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'; " <>
        "script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; " <>
        "font-src 'self'; connect-src 'self' ws: wss:; object-src 'none'",
    "cross-origin-opener-policy" => "same-origin",
    "cross-origin-resource-policy" => "same-origin",
    "permissions-policy" => "camera=(), microphone=(), geolocation=(), payment=(), usb=()",
    "referrer-policy" => "no-referrer"
  }

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShareSecretWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, @security_headers
  end

  scope "/", ShareSecretWeb do
    pipe_through :browser

    live_session :default do
      live "/", HomeLive.Index, :index
      live "/:id", HomeLive.Show, :show
    end
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
