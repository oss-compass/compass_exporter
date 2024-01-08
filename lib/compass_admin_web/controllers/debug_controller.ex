defmodule CompassAdminWeb.DebugController do
  use CompassAdminWeb, :controller
  import CompassAdminWeb.Helpers

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
end
