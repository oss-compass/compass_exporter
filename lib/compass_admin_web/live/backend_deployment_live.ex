defmodule CompassAdminWeb.BackendDeploymentLive do
  use CompassAdminWeb, :live_view

  alias CompassAdmin.User
  alias CompassAdmin.Agents.BackendAgent

  import CompassAdmin.Utils, only: [apm_call: 3]

  @impl true
  def mount(_params, %{"current_user" => current_user}, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, 5000)

    state = apm_call(BackendAgent, :get_state, [])
    last_deploy_user = User.find(state.last_deploy_id, preloads: :login_binds)
    last_trigger_user = User.find(state.last_trigger_id, preloads: :login_binds)
    last_deployer = if last_deploy_user, do: List.first(last_deploy_user.login_binds)
    last_trigger = if last_trigger_user, do: List.first(last_trigger_user.login_binds)
    can_deploy = current_user.role_level >= User.backend_dev_role()

    {:ok,
     assign(socket,
       title: "Backend recent deployment logs",
       agent_state: state,
       can_deploy: can_deploy,
       current_user: current_user,
       last_trigger: last_trigger,
       last_deployer: last_deployer
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    case socket.assigns.live_action do
      :index ->
        {:noreply, assign(socket, action: :index)}
    end
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, 5000)

    state = apm_call(BackendAgent, :get_state, [])
    last_deploy_user = User.find(state.last_deploy_id, preloads: :login_binds)
    last_trigger_user = User.find(state.last_trigger_id, preloads: :login_binds)
    last_deployer = if last_deploy_user, do: List.first(last_deploy_user.login_binds)
    last_trigger = if last_trigger_user, do: List.first(last_trigger_user.login_binds)

    {:noreply,
     assign(socket,
       agent_state: state,
       last_trigger: last_trigger,
       last_deployer: last_deployer
     )}
  end

  @impl true
  def handle_event("deploy", _value, socket) do
    apm_call(BackendAgent, :execute, [socket.assigns.current_user.id])
    Process.sleep(1000)
    state = apm_call(BackendAgent, :get_state, [])
    last_deploy_user = User.find(state.last_deploy_id, preloads: :login_binds)
    last_trigger_user = User.find(state.last_trigger_id, preloads: :login_binds)
    last_deployer = if last_deploy_user, do: List.first(last_deploy_user.login_binds)
    last_trigger = if last_trigger_user, do: List.first(last_trigger_user.login_binds)

    {:noreply,
     assign(socket,
       agent_state: state,
       last_trigger: last_trigger,
       last_deployer: last_deployer
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.deployment_page
      title={@title}
      agent_state={@agent_state}
      last_trigger={@last_trigger}
      last_deployer={@last_deployer}
      can_deploy={@can_deploy}
    >
    </.deployment_page>
    """
  end
end
