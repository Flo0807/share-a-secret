# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :share_secret, env: Mix.env()

config :share_secret,
  ecto_repos: [ShareSecret.Repo]

config :share_secret, ShareSecret.Repo, migration_primary_key: [type: :uuid]

# Configures the endpoint
config :share_secret, ShareSecretWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ShareSecretWeb.ErrorHTML, json: ShareSecretWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ShareSecret.PubSub,
  live_view: [signing_salt: "JBSGcAt2"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.8",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.11",
  default: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
