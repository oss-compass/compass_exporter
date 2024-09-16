defmodule CompassAdminWeb.DebugController do
  alias Plug.Conn
  alias CompassAdmin.DockerTokenCacher
  alias CompassAdmin.DockerTokenCacher.Token

  use CompassAdminWeb, :controller

  import CompassAdminWeb.Helpers

  @config Application.get_env(:compass_admin, CompassAdmin.Services.ExportMetrics, %{})
  @client_options [proxy: @config[:proxy], timeout: 180_000, recv_timeout: 3_600_000]

  def webhook(conn, _params) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    pretty_json(conn,
      %{
        body: body,
        params: conn.params,
        body_params: conn.body_params,
        headers: Enum.into(conn.req_headers, %{})
      }
    )
  end

  def docker_registry_proxy(conn, _params) do
    params =
      ReverseProxyPlug.init(
        upstream: "https://registry-1.docker.io",
        client_options: @client_options,
        response_mode: :buffer,
        preserve_host_header: false
      )

    {:ok, body, conn} = Plug.Conn.read_body(conn)

    case DockerTokenCacher.get(conn) do
      %Token{token: token} ->
        auth_conn =
          %Conn{}
          |> Map.merge(conn)
          |> Conn.put_req_header("Authorization", "bearer #{token}")

        auth_conn
        |> ReverseProxyPlug.request(body, params)
        |> handle_redirect(auth_conn)
        |> ReverseProxyPlug.response(conn, params)
      {:error, reason} ->
        json(conn, %{error: reason})
    end
  end

  def handle_redirect({:ok, %{status_code: code, headers: headers, request: %{headers: req_headers}}}, conn)  when code > 300 and code < 400 do
    next = get_location(headers)
    method =
      conn.method
      |> String.downcase()
      |> String.to_existing_atom()
    apply(HTTPoison, method, [next, remove_host(req_headers), @client_options])
  end

  def handle_redirect(resp, _), do: resp

  defp get_location(headers) do
    {_h, location} =
      Enum.find(headers, fn {header, _location} ->
        String.downcase(header) == "location"
      end)

    location
  end

  defp remove_host(headers) do
    Enum.reject(headers, fn {header, _} ->
      String.downcase(header) == "host"
    end)
  end
end
