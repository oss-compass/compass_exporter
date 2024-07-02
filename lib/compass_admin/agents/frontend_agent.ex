defmodule CompassAdmin.Agents.FrontendAgent do
  use GenServer

  import Ecto.Query
  alias CompassAdmin.Repo
  alias CompassAdmin.User

  @max_lines 5000
  @agent_svn "frontend_v1"

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok,
     restore() ||
       %{
         state: :ok,
         logs: [
           "Welcome to use OSS Compass Admin Deployments.\n",
           "This page provides you with an overview of the last trigger and deploy information for your application. >_< \n"
         ],
         last_trigger_id: nil,
         last_triggered_at: nil,
         last_triggered_result: nil,
         last_deploy_id: nil,
         last_deploy_at: nil,
         last_deploy_result: nil
       }}
  end

  def execute(trigger_id) do
    GenServer.cast(__MODULE__, {:deploy, trigger_id})
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def append_log(log) do
    GenServer.cast(__MODULE__, {:append, log})
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:update_deploy_state, deploy_state, last_deploy_id, last_deploy_result}, state) do
    last_triggered_result =
      if state.last_triggered_result == {:ok, "processing"} do
        last_deploy_result
      else
        state.last_triggered_result
      end

    new_state = %{
      state
      | state: deploy_state,
        last_deploy_id: last_deploy_id,
        last_deploy_at: Timex.now(),
        last_deploy_result: last_deploy_result,
        last_triggered_result: last_triggered_result
    }

    save(new_state)

    {:noreply, new_state}
  end

  def handle_cast({:append, log}, state) do
    {:noreply, %{state | logs: [log | Enum.take(state.logs, @max_lines)]}}
  end

  def handle_cast({:deploy, trigger_id}, state) do
    user = Repo.one(from(u in User, where: u.id == ^trigger_id))

    new_state = %{state | last_trigger_id: trigger_id, last_triggered_at: Timex.now()}

    if user && user.role_level >= User.frontend_dev_role() do
      case state do
        %{state: :ok} ->
          Task.async(fn ->
            GenServer.cast(
              __MODULE__,
              {:update_deploy_state, :processing, trigger_id, {:ok, "processing"}}
            )

            do_deployment(trigger_id)
          end)

          new_state = %{
            new_state
            | last_triggered_result: {:ok, "processing"},
              state: :processing
          }

          save(new_state)
          {:noreply, new_state}

        _ ->
          new_state = %{
            new_state
            | last_triggered_result: {:error, "no ready for new deployment"}
          }

          save(new_state)
          {:noreply, new_state}
      end
    else
      new_state = %{new_state | last_triggered_result: {:error, "no permission"}}
      save(new_state)
      {:noreply, new_state}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp do_deployment(trigger_id) do
    [input: input, execute: execute] = Application.fetch_env!(:compass_admin, __MODULE__)

    Exile.stream(["bash", "-l", "-c", execute], input: input, stderr: :consume)
    |> Stream.each(fn stream ->
      case stream do
        {:stdout, data} -> log(data)
        {:stderr, msg} -> log(msg)
        {:exit, {:status, code}} ->
          msg = "exit with status: #{code}"
          log(msg)
          if code != 0 do
            GenServer.cast(__MODULE__, {:update_deploy_state, :ok, trigger_id, {:error, msg}})
          else
            GenServer.cast(__MODULE__, {:update_deploy_state, :ok, trigger_id, {:ok, :success}})
          end
      end
    end)
    |> Stream.run()
  end

  defp log(message) do
    now = Timex.now() |> Timex.format!("%Y-%m-%d %H:%M:%S", :strftime)
    append_log("[#{now}] #{message}")
  end

  defp save(state) do
    Redix.command(:redix, ["SET", "compass:admin:#{@agent_svn}", :erlang.term_to_binary(state)])
  end

  defp restore() do
    with {:ok, cached} <- Redix.command(:redix, ["GET", "compass:admin:#{@agent_svn}"]) do
      if cached != nil, do: :erlang.binary_to_term(cached), else: nil
    end || nil
  end
end
