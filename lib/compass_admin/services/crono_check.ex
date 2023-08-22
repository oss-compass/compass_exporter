defmodule CompassAdmin.Services.CronoCheck do
  @config Application.get_env(:compass_admin, __MODULE__, %{})

  def start() do
    alives =
      [node() | Node.list()]
      |> Enum.map(&check_crono/1)
      |> Enum.sum
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
    random_node()
    |> :rpc.call(__MODULE__, :do_start_crono, [])
    |> IO.inspect(label: "[start crono]")
  end

  def stop_crono() do
    random_node()
    |> :rpc.call(__MODULE__, :do_stop_crono, [])
    |> IO.inspect(label: "[stop crono]")
  end

  def list_methods() do
    build_xml_rpc("system.listMethods", [])
    |> call_rpc
  end

  def list_processes() do
    build_xml_rpc("supervisor.getAllProcessInfo", [])
    |> call_rpc
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

  defp build_xml_rpc(method, params) do
    request =
      %XMLRPC.MethodCall{method_name: method, params: params}
      |> XMLRPC.encode!()
    Finch.build(
      :post,
      @config[:supervisor_api],
      [{"Content-Type", "text/xml"}, {"Authorization", "Basic #{@config[:basic_auth]}"}],
      request
    )
  end

  defp call_rpc(request) do
    with {:ok, resp} <- Finch.request(request, CompassFinch) do
      XMLRPC.decode(resp.body)
    end
  end

  defp random_node() do
    [node() | Node.list()]
    |> Enum.random()
  end
end
