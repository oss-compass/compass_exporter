defmodule CompassAdmin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies)

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
      # Start the Endpoint (http/https)
      CompassAdminWeb.Endpoint,
      # Start a worker by calling: CompassAdmin.Worker.start_link(arg)
      # {CompassAdmin.Worker, arg}
      CompassAdmin.Scheduler,
      {Highlander, CompassAdmin.GlobalScheduler}
    ]

    CompassAdmin.Plug.MetricsExporter.setup()
    Metrics.CompassInstrumenter.setup()


    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CompassAdmin.Supervisor]
    init_state = Supervisor.start_link(children, opts)
    # Custom jobs
    Enum.map([:export_metrics, :weekly_metrics, :monthly_metrics], &CompassAdmin.Scheduler.run_job/1)
    init_state
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CompassAdminWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
