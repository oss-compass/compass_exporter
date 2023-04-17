defmodule CompassAdminWeb.PageController do
  use CompassAdminWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
