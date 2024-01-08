defmodule CompassAdminWeb.Helpers do
  @spec pretty_json(Plug.Conn.t(), term) :: Plug.Conn.t()
  def pretty_json(conn, data) do
    response = Phoenix.json_library().encode_to_iodata!(data, [pretty: true])
    Plug.Conn.send_resp(conn, conn.status || 200, response)
  end
end
