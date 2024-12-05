defmodule CompassAdminWeb.Router do
  use CompassAdminWeb, :router

  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {Backoffice.LayoutView, :backoffice}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug CompassAdminWeb.Plugs.VerifyAdminPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CompassAdminWeb do
    pipe_through :api
    match :*, "/v2/*path", DebugController, :docker_registry_proxy
    match :*, "/api/*path", DebugController, :apm_proxy
  end

  scope "/admin", CompassAdminWeb do
    pipe_through :browser
    live "/", PageLive, :index
    live "/users", UserLive
    live "/dockers", DockerServicesLive, :index
    live "/configurations", ConfigurationLive, :index

    for {key, _path} <- Application.get_env(:compass_admin, :configurations, []) do
      live "/configurations/#{key}", ConfigurationLive, key
    end

    live "/gitee/repos", GiteeReposLive, :index
    live "/gitee/repos/bulk", GiteeReposLive, :bulk

    live "/gitee/issues", GiteeIssuesLive, :index
    live "/gitee/issues/bulk", GiteeIssuesLive, :bulk

    live "/deployments/gateway", GatewayDeploymentLive, :index
    live "/deployments/backend", BackendDeploymentLive, :index
    live "/deployments/frontend", FrontendDeploymentLive, :index

    live_dashboard "/dashboard",
      metrics: CompassAdminWeb.Telemetry,
      ecto_repos: [CompassAdmin.Repo],
      ecto_mysql_extras_options: [long_running_queries: [threshold: 200]]
  end

  scope "/debug", CompassAdminWeb do
    pipe_through :api
    match :*, "/webhook", DebugController, :webhook
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
