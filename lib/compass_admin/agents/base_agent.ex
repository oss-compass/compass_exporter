defmodule CompassAdmin.Agents.BaseAgent do
  @max_lines 5000

  import Ecto.Query
  alias CompassAdmin.Repo
  alias CompassAdmin.User

  def init(cache_key) do
    restore(cache_key)
    |> Map.put(:cache_key, cache_key)
  end

  def deploy(module, state, trigger_id, role_required) do
    user = Repo.one(from(u in User, where: u.id == ^trigger_id))
    new_state = %{state | last_trigger_id: trigger_id, last_triggered_at: Timex.now()}

    if user && user.role_level >= role_required do
      case state do
        %{state: :ok} ->
          Task.async(fn ->
            module.update_deploy_state(:processing, trigger_id, {:ok, "processing"})
            do_deploy(trigger_id, module)
          end)

          new_state = %{
            new_state
            | last_triggered_result: {:ok, "processing"},
              state: :processing
          }

          save(state[:cache_key], new_state)
          new_state

        _ ->
          new_state = %{
            new_state
            | last_triggered_result: {:error, "no ready for new deployment"}
          }

          save(state[:cache_key], new_state)
          new_state
      end
    else
      new_state = %{new_state | last_triggered_result: {:error, "no permission"}}
      save(state[:cache_key], new_state)
      new_state
    end
  end

  def do_deploy(trigger_id, module) do
    [input: input, execute: execute] = Application.fetch_env!(:compass_admin, module)

    Exile.stream(["bash", "-l", "-c", execute], input: input, stderr: :consume)
    |> Stream.each(fn stream ->
      case stream do
        {:stdout, data} ->
          module.append_log(data)

        {:stderr, msg} ->
          module.append_log(msg)

        {:exit, {:status, code}} ->
          msg = "exit with status: #{code}"
          module.append_log(msg)

          if code != 0 do
            module.update_deploy_state(:ok, trigger_id, {:error, msg})
          else
            module.update_deploy_state(:ok, trigger_id, {:ok, :success})
          end
      end
    end)
    |> Stream.run()
  end

  def append_log(state, log) do
    now = Timex.now() |> Timex.format!("%Y-%m-%d %H:%M:%S", :strftime)
    %{state | logs: ["[#{now}] #{log}" | Enum.take(state.logs, @max_lines)]}
  end

  def update_deploy_state(state, deploy_state, last_deploy_id, last_deploy_result) do
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

    save(state[:cache_key], new_state)

    new_state
  end

  defp restore(cache_key) do
    with {:ok, cached} <- Redix.command(:redix, ["GET", "compass:admin:#{cache_key}"]) do
      if cached != nil, do: :erlang.binary_to_term(cached), else: nil
    end ||
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
      }
  end

  defp save(cache_key, state) do
    Redix.command(:redix, ["SET", "compass:admin:#{cache_key}", :erlang.term_to_binary(state)])
  end
end
