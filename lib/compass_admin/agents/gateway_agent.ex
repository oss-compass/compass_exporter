defmodule CompassAdmin.Agents.GatewayAgent do
  use GenServer

  alias CompassAdmin.User
  alias CompassAdmin.Agents.DeployAgent

  @agent_svn "gateway_v1"

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, DeployAgent.init(@agent_svn)}
  end

  def execute(trigger_id) do
    GenServer.cast(__MODULE__, {:deploy, trigger_id})
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def update_deploy_state(deploy_state, last_deploy_id, last_deploy_result) do
    GenServer.cast(
      __MODULE__,
      {:update_deploy_state, deploy_state, last_deploy_id, last_deploy_result}
    )
  end

  def append_log(log) do
    GenServer.cast(__MODULE__, {:append, log})
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:update_deploy_state, deploy_state, last_deploy_id, last_deploy_result}, state) do
    {:noreply,
     DeployAgent.update_deploy_state(
       state,
       deploy_state,
       last_deploy_id,
       last_deploy_result
     )}
  end

  def handle_cast({:append, log}, state) do
    {:noreply, DeployAgent.append_log(state, log)}
  end

  def handle_cast({:deploy, trigger_id}, state) do
    {:noreply, DeployAgent.deploy(__MODULE__, state, trigger_id, User.gateway_dev_role())}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
