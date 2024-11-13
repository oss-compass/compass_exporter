defmodule CompassAdminWeb.DebugController do
  alias Plug.Conn
  alias ReverseProxyPlug.HTTPClient
  alias CompassAdmin.DockerTokenCacher
  alias CompassAdmin.DockerTokenCacher.Token

  use CompassAdminWeb, :controller

  import CompassAdminWeb.Helpers

  @config Application.get_env(:compass_admin, CompassAdmin.Services.ExportMetrics, %{})
  @apm_config Application.get_env(:compass_admin, :apm, %{})
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

  def apm_proxy(conn, _params) do
    upstream = @apm_config[:upstream]

    params =
      ReverseProxyPlug.init(
        upstream: upstream,
        client_options: [proxy: nil, timeout: 1_000, recv_timeout: 2_000],
        response_mode: :buffer,
        preserve_host_header: false
      )
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    auth_conn =
      %Conn{}
      |> Map.merge(conn)
      |> Conn.put_req_header("Authorization", "Basic #{@apm_config[:basic_auth]}")

    auth_conn
    |> ReverseProxyPlug.request(body, params)
    |> ReverseProxyPlug.response(conn, params)
  end


  def docker_registry_proxy(conn, _params) do

    upstream = "https://registry-1.docker.io"

    params =
      ReverseProxyPlug.init(
        upstream: upstream,
        client_options: @client_options,
        response_mode: :buffer,
        preserve_host_header: false
      )

    stream_params =
      ReverseProxyPlug.init(
        upstream: upstream,
        client_options: @client_options,
        response_mode: :stream,
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
        |> handle_redirect_resp()
        |> ReverseProxyPlug.response(conn, if(Enum.member?(conn.path_info, "blobs"), do: stream_params, else: params))
      {:error, reason} ->
        json(conn, %{error: reason})
    end
  end

  def handle_redirect({:ok, %{status_code: code, headers: headers, request: %{headers: req_headers}}}, conn)
  when code > 300 and code < 400 do
    next = get_location(headers)
    final_options = if Enum.member?(conn.path_info, "blobs"),
      do: @client_options |> Keyword.put_new(:stream_to, self()),
      else: @client_options
  method =
    conn.method
    |> String.downcase()
    |> String.to_existing_atom()
  apply(HTTPoison, method, [next, remove_host(req_headers), final_options])
  end

  def handle_redirect(resp, _), do: resp

  def handle_redirect_resp({:ok, %HTTPoison.AsyncResponse{} = _resp}) do
    {:ok,
     Stream.unfold(nil, fn _ ->
       receive do
         %HTTPoison.AsyncStatus{code: code} ->
           {{:status, code}, nil}

           %HTTPoison.AsyncHeaders{headers: headers} ->
           {{:headers, headers}, nil}

         %HTTPoison.AsyncChunk{chunk: chunk} ->
           {{:chunk, chunk}, nil}

         %HTTPoison.Error{reason: reason} ->
           {{:error, %HTTPClient.Error{reason: reason}}, nil}

         %HTTPoison.AsyncEnd{} ->
           nil
       end
     end)}
  end

  def handle_redirect_resp(resp), do: resp

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
