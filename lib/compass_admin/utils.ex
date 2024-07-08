defmodule CompassAdmin.Utils do

  def apm_call(module, func, args) do
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
