# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

only_web = if System.get_env("ONLY_WEB") do
  IO.inspect("building with only_web flag", label: "build")
  true
else
  false
end

config :compass_admin,
  ecto_repos: [CompassAdmin.Repo]

# Configures the endpoint
config :compass_admin, CompassAdminWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: CompassAdminWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: CompassAdmin.PubSub,
  live_view: [signing_salt: "Fd8SWPu3"]

config :compass_admin, :basic_auth, username: "username", password: "password"

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :compass_admin, CompassAdmin.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false
config :swoosh, local: false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.15.5",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/admin/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :prometheus, :vm_msacc_collector_metrics, []
config :prometheus, :vm_memory_collector_metrics, []
config :prometheus, :vm_statistics_collector_metrics, []
config :prometheus, :vm_system_info_collector_metrics, []

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :compass_admin, CompassAdmin.GlobalScheduler,
  jobs: if(only_web, do: [], else: [
    queue_schedule: [
      schedule: {:extended, "*/30"},
      task: {CompassAdmin.Services.QueueSchedule, :start, []},
      run_strategy: Quantum.RunStrategy.Local,
      overlap: false
    ],
    crono_check: [
      schedule: "* * * * *",
      task: {CompassAdmin.Services.CronoCheck, :start, []},
      run_strategy: Quantum.RunStrategy.Local,
      overlap: false
    ]
  ])

config :compass_admin, CompassAdmin.Scheduler,
  jobs: if(only_web, do: [], else: [
    export_metrics: [
      schedule: "*/30 * * * *",
      task: {CompassAdmin.Services.ExportMetrics, :start, []},
      run_strategy: {Quantum.RunStrategy.All, [:"compass_admin@app-front-1"]},
      overlap: false
    ],
    weekly_metrics: [
      schedule: "0 12 * * *",
      task: {CompassAdmin.Services.ExportMetrics, :weekly, []},
      run_strategy: {Quantum.RunStrategy.All, [:"compass_admin@app-front-1"]},
      overlap: false
    ],
    sitemap_generate: [
      schedule: "0 12 * * *",
      task: {CompassAdmin.Services.SitemapGenerate, :start, []},
      run_strategy: Quantum.RunStrategy.Local,
      overlap: false
    ],
    monthly_metrics: [
      schedule: "0 12 * * 6",
      task: {CompassAdmin.Services.ExportMetrics, :monthly, []},
      run_strategy: {Quantum.RunStrategy.All, [:"compass_admin@app-front-1"]},
      overlap: false
    ],
  ])

config :libcluster,
  topologies: [
    compass_admin: [
      strategy: Cluster.Strategy.Gossip,
      config: [
        secret: if(only_web, do: "compass-admin-web", else: "compass-admin")
      ]
    ]
  ]

config :petal_components,
       :error_translator_function,
       {CompassAdminWeb.ErrorHelpers, :translate_error}

config :tailwind,
  version: "3.1.8",
  default: [
    args: ~w(
         --config=tailwind.config.js
         --input=css/app.css
         --output=../priv/static/admin/assets/app.css
       ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
