defmodule CompassAdminWeb.FrontendDeploymentLive do
  use CompassAdminWeb, :live_view

  alias CompassAdmin.User
  alias CompassAdmin.Agents.FrontendAgent

  @impl true
  def mount(_params, %{"current_user" => current_user}, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, 5000)

    state = apm_call(FrontendAgent, :get_state, [])
    last_deploy_user = User.find(state.last_deploy_id, preloads: :login_binds)
    last_trigger_user = User.find(state.last_trigger_id, preloads: :login_binds)
    last_deployer = if last_deploy_user, do: List.first(last_deploy_user.login_binds)
    last_trigger = if last_trigger_user, do: List.first(last_trigger_user.login_binds)
    can_deploy = current_user.role_level >= User.frontend_dev_role()

    {:ok,
     assign(socket,
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

    state = apm_call(FrontendAgent, :get_state, [])
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
    apm_call(FrontendAgent, :execute, [socket.assigns.current_user.id])
    Process.sleep(1000)
    state = apm_call(FrontendAgent, :get_state, [])
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
      agent_state={@agent_state}
      last_trigger={@last_trigger}
      last_deployer={@last_deployer}
      can_deploy={@can_deploy}
    >
    </.deployment_page>
    """
  end

  defp apm_call(module, func, args) do
    :rpc.call(apm_node(), module, func, args)
  end

  defp apm_node() do
    [node() | Node.list()]
    |> Enum.filter(fn node ->
      node_name = to_string(node)
      String.contains?(node_name, "apm")
    end)
    |> List.first()
  end
end
