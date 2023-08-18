import Config

# Configure your database
config :compass_admin, CompassAdmin.Repo,
  username: "username",
  password: "password",
  database: "database",
  hostname: "localhost",
  port: 3306,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :compass_admin, CompassAdmin.Cluster,
  url: "http://localhost:9200",
  username: "admin",
  password: "admin"

config :amqp,
  connections: [
    compass_conn: [url: "amqp://admin:admin@localhost:5672"],
  ],
  channels: [
    compass_chan: [connection: :compass_conn]
  ]

config :compass_admin, CompassAdmin.Services.QueueSchedule,
  worker_num: 16,
  max_group: 1,
  host: "localhost",
  port: 5672,
  username: "admin",
  password: "admin",
  queues: [
    [major_queue: "analyze_queue_v1", minior_queue: "analyze_queue_v1_temp", pending_queue: "analyze_queue_v1_temp_bak"]
  ]

config :compass_admin, CompassAdmin.Services.CronoCheck,
  process_name: "compass-web-crontab",
  supervisor_api: "http://localhost:19999/RPC2",
  basic_auth: "basic_auth"


config :compass_admin, CompassAdmin.Services.ExportMetrics,
  proxy: "http://127.0.0.1:1081",
  github_tokens: [
  ],
  projects_information_path: "/home/ef/Documents/compass-projects-information",
  all_queues: [
    [name: "analyze_queue_v1", desc: "Major working queue"],
    [name: "analyze_queue_v1_temp", desc: "Minor working queue"],
    [name: "analyze_queue_v1_temp_bak", desc: "Pendding queue"],
    [name: "lab_queue_v1", desc: "Lab metric working queue"],
    [name: "summary_queue_v1", desc: "Summary metric working queue"],
    [name: "analyze_queue_v2", desc: "Community metric working queue"],
    [name: "submit_task_v1", desc: "Pull Request sumbit queue"],
    [name: "yaml_check_v1", desc: "Yaml file format check queue"],
    [name: "subscriptions_update_v1", desc: "Subscriptions update queue"],
  ]

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with esbuild to bundle .js and .css sources.
config :compass_admin, CompassAdminWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  server: true,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "47TFd8fpLTZROcN4Lxz/OQ5fz4hVFMNCsSxHKwSrRGZGxDcWKyGH+1uxAtGYn1/Q",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Note that this task requires Erlang/OTP 20 or later.
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :compass_admin, CompassAdminWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/compass_admin_web/(live|views)/.*(ex)$",
      ~r"lib/compass_admin_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
