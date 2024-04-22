defmodule CompassAdmin.Services.Docker do
  @config Application.get_env(:compass_admin, __MODULE__, %{})

  def list_processes() do
    Enum.reduce(all_nodes(), %{}, fn node, ret ->
      Map.put(ret, to_string(node), :rpc.call(node, __MODULE__, :do_list_processes, []))
    end)
  end

  def do_list_processes() do
    Exile.stream!(@config[:ps], input: @config[:input])
    |> Enum.into("")
    |> String.trim_trailing()
    |> String.split("\n")
    |> Enum.map(&String.trim(&1, "\"") )
    |> Enum.map(&Jason.decode!/1)
  end

  defp all_nodes() do
    [node() | Node.list()]
  end
end
