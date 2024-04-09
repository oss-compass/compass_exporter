defmodule CompassAdmin.Services.CronoCheck do
  @config Application.get_env(:compass_admin, __MODULE__, %{})

  def start() do
    alives =
      all_app_nodes()
      |> Enum.map(&check_crono/1)
      |> Enum.sum()

    cond do
      alives < 1 -> start_crono()
      alives > 1 -> stop_crono()
      true -> IO.inspect("work well", label: "[crono]")
    end
  end

  def check_crono(node) do
    :rpc.call(node, __MODULE__, :do_check_crono, [])
  end

  def start_crono() do
    random_app_node()
    |> :rpc.call(__MODULE__, :do_start_crono, [])
    |> IO.inspect(label: "[start crono]")
  end

  def stop_crono() do
    random_app_node()
    |> :rpc.call(__MODULE__, :do_stop_crono, [])
    |> IO.inspect(label: "[stop crono]")
  end

  def list_methods() do
    build_xml_rpc("system.listMethods", [])
    |> call_rpc
  end

  def list_processes() do
    Enum.reduce(all_nodes(), %{}, fn node, ret ->
      Map.put(ret, to_string(node), :rpc.call(node, __MODULE__, :do_list_processes, []))
    end)
  end

  def do_list_processes() do
    with {:ok, %{param: processes}} <-
           build_xml_rpc("supervisor.getAllProcessInfo", [])
           |> call_rpc do
      processes
    end || []
  end

  def do_start_crono() do
    request = build_xml_rpc("supervisor.startProcess", [@config[:process_name]])

    with {:ok, resp} <- Finch.request(request, CompassFinch) do
      XMLRPC.decode(resp.body)
    end
  end

  def do_stop_crono() do
    request = build_xml_rpc("supervisor.stopProcess", [@config[:process_name]])

    with {:ok, resp} <- Finch.request(request, CompassFinch) do
      XMLRPC.decode(resp.body)
    end
  end

  def do_check_crono() do
    request = build_xml_rpc("supervisor.getProcessInfo", [@config[:process_name]])

    with {:ok, resp} <- Finch.request(request, CompassFinch),
         {:ok, %{param: %{"statename" => "RUNNING"}}} <- XMLRPC.decode(resp.body) do
      1
    else
      _ -> 0
    end
  end

  defp build_xml_rpc(method, params, api_url \\ @config[:supervisor_api]) do
    request =
      %XMLRPC.MethodCall{method_name: method, params: params}
      |> XMLRPC.encode!()

    Finch.build(
      :post,
      api_url,
      [{"Content-Type", "text/xml"}, {"Authorization", "Basic #{@config[:basic_auth]}"}],
      request
    )
  end

  defp call_rpc(request) do
    with {:ok, resp} <- Finch.request(request, CompassFinch) do
      XMLRPC.decode(resp.body)
    end
  end

  defp random_app_node() do
    all_app_nodes()
    |> Enum.random()
  end

  defp all_app_nodes() do
    Enum.filter(all_nodes(), fn node ->
      node_name = to_string(node)
      String.contains?(node_name, "app-front") || String.contains?(node_name, "grimoirelab")
    end)
  end

  defp all_nodes() do
    [node() | Node.list()]
  end
end
