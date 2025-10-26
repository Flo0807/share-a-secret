import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :share_secret, ShareSecret.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "secret_sharing_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :share_secret, ShareSecretWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "VL0zYLW9UXhe/ij6Nn98z9LchTP7CV8/gRdESdhjLqE4l/1wg1NcACDBg7LoIARp",
  server: true

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_test,
  endpoint: ShareSecretWeb.Endpoint,
  otp_app: :share_secret,
  playwright: [
    browser: :chromium,
    browser_launch_timeout: 10_000,
    timeout: 250,
    trace: System.get_env("PLAYWRIGHT_TRACE", "false") in ~w(t true),
    trace_dir: "tmp"
  ]
