defmodule ShareSecret.MixProject do
  use Mix.Project

  def project do
    [
      app: :share_secret,
      version: "0.7.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      gettext: [write_reference_line_numbers: false]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ShareSecret.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Core
      {:phoenix, "== 1.7.20"},
      {:phoenix_html, "== 4.2.1"},
      {:phoenix_live_view, "== 1.0.5"},
      {:bandit, "== 1.6.8"},

      # Database and Persistence
      {:ecto_sql, "== 3.12.1"},
      {:phoenix_ecto, "== 4.6.3"},
      {:postgrex, "== 0.20.0"},

      # Monitoring and Telemetry
      {:phoenix_live_dashboard, "== 0.8.6"},
      {:telemetry_metrics, "== 1.1.0"},
      {:telemetry_poller, "== 1.1.0"},

      # UI
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # Utilities
      {:gettext, "== 0.26.2"},
      {:jason, "== 1.4.4"},
      {:timex, "== 3.7.11"},

      # Dev and Test
      {:esbuild, "== 0.9.0", runtime: Mix.env() == :dev},
      {:tailwind, "== 0.3.1", runtime: Mix.env() == :dev},
      {:phoenix_live_reload, "== 1.5.3", only: :dev},
      {:tailwind_formatter, "== 0.4.2", only: [:dev, :test], runtime: false},
      {:credo, "== 1.7.11", only: [:dev, :test], runtime: false},
      {:floki, "== 0.37.0", only: :test},
      {:mox, "== 1.2.0", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
