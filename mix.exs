defmodule CompassAdmin.MixProject do
  use Mix.Project

  def project do
    [
      app: :compass_admin,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [
        compass_admin: [
          overwrite: true
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {CompassAdmin.Application, []},
      extra_applications: [:logger, :runtime_tools, :prometheus_ex, :prometheus_plugs, :os_mon]
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
      {:phoenix, "~> 1.6.6"},
      {:phoenix_ecto, "~> 4.4"},
      {:exile, "~> 0.9.1"},
      {:ecto_sql, "~> 3.6"},
      {:myxql, "~> 0.6.0"},
      {:amqp, "~> 3.2"},
      {:redix, "~> 1.1"},
      {:redlock, "~> 1.0"},
      {:ex_marshal, "0.0.13"},
      {:timex, "~> 3.7"},
      {:libcluster, "~> 3.3"},
      {:xmlrpc, "~> 1.4"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.18.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.7"},
      {:highlander, "~> 0.2.1"},
      {:ecto_mysql_extras, "~> 0.3"},
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:quantum, "~> 3.0"},
      {:vapor, "~> 0.10.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:prometheus_ex, "~> 3.0"},
      {:prometheus_plugs, "~> 1.1"},
      {:snap, "~> 0.8"},
      {:finch, "~> 0.13"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:sitemapper, "~> 0.6"},
      {:plug_cowboy, "~> 2.5"},
      {:petal_components, "~> 0.18.0"},
      {:backoffice, path: "backoffice"},
      {:tailwind, "~> 0.1", runtime: Mix.env() == :dev},
      {:decimal, "~> 2.0", override: true}
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
      setup: ["deps.get", "ecto.setup", "tailwind.install", "esbuild.install"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": [
        "tailwind default --minify",
        "esbuild default --minify",
        "phx.digest"
      ],
      external_bins: ["cmd cd scoop/scoop; go build -o ../../priv/bin/scoop"]
    ]
  end
end
