defmodule CompassAdmin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)
    redis_url = Application.get_env(:compass_admin, :redis_url, "")
    %{host: redis_host, port: redis_port, userinfo: userinfo, path: path} = URI.parse(redis_url)
    [riak_host, riak_port] = Application.get_env(:compass_admin, :riak, ['127.0.0.1', 8087])

    auth =
      case userinfo do
        ":" <> auth -> auth
        _ -> userinfo
      end

    database =
      case path do
        "/" <> database -> Integer.parse(database) |> elem(0)
        _ -> 0
      end

    children = [
      # Start Cluster Supervisor
      {Cluster.Supervisor, [topologies, [name: CompassAdmin.ClusterSupervisor]]},
      # Start the Ecto repository
      CompassAdmin.Repo,
      # Start the Elasticsearch cluster
      CompassAdmin.Cluster,
      # Start finch pool
      {Finch, name: CompassFinch},
      # Start the Telemetry supervisor
      CompassAdminWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: CompassAdmin.PubSub},
      CompassAdmin.DockerTokenCacher,
      # Start the Endpoint (http/https)
      CompassAdminWeb.Endpoint,
      # Start Riak
      :poolboy.child_spec(:riak_pool, riak_config(), [riak_host, riak_port]),
      # Start Redix
      {Redix, {System.get_env("REDIS_URL") || redis_url, [name: :redix, backoff_max: 2_000, timeout: 2_000], }},
      {Redlock,
       [
         pool_size: 2,
         drift_factor: 0.01,
         max_retry: 5,
         retry_interval_base: 300,
         retry_interval_max: 3_000,
         reconnection_interval_base: 500,
         reconnection_interval_max: 5_000,
         servers: [
           [host: redis_host, port: redis_port, auth: auth, database: database]
         ]
       ]},
      # {CompassAdmin.Worker, arg}
      CompassAdmin.Scheduler,
      {Highlander, CompassAdmin.GlobalScheduler},
      # Exec agent
      {CompassAdmin.Agents.ExecAgent, []},
      # Deployment agents
      {CompassAdmin.Agents.BackendAgent, []},
      {CompassAdmin.Agents.FrontendAgent, []}
    ]

    CompassAdmin.Plug.MetricsExporter.setup()
    Metrics.CompassInstrumenter.setup()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CompassAdmin.Supervisor]
    init_state = Supervisor.start_link(children, opts)
    # Custom jobs
    Enum.map(
      [:export_metrics, :weekly_metrics, :monthly_metrics, :sitemap_generate],
      &CompassAdmin.Scheduler.run_job/1
    )

    init_state
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CompassAdminWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp riak_config() do
    [
      name: {:local, CompassAdmin.RiakPool},
      worker_module: CompassAdmin.RiakPool,
      size: 5,
      max_overflow: 0
    ]
  end
end
