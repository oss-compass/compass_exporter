defmodule CompassAdminWeb.DebugController do
  use CompassAdminWeb, :controller

  def webhook(conn, _params) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    json(conn,
      %{
        body: body,
        params: conn.params,
        body_params: conn.body_params,
        headers: Enum.into(conn.req_headers, %{})
      }
    )
  end
end
