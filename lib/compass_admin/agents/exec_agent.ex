defmodule CompassAdmin.Agents.ExecAgent do
  use GenServer

  @exec_timeout 60_000

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    {:ok, args}
  end

  def shell_exec(cmd) do
    GenServer.call(__MODULE__, {:shell_exec, cmd}, @exec_timeout)
  end

  def handle_call({:shell_exec, cmd}, _from, state) do
    try do
      result =
        Exile.stream!(["bash", "-l", "-c", cmd])
        |> Enum.into("")

      {:reply, {:ok, result}, state}
    rescue
      e in Exile.Stream.AbnormalExit -> {:reply, {:error, e.exit_status, e.message}, state}
      _ -> {:reply, {:error, -1, "Unknown error"}, state}
    end
  end
end
