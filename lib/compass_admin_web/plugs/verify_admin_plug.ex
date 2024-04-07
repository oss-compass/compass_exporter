defmodule CompassAdminWeb.Plugs.VerifyAdminPlug do
  import Plug.Conn
  import Ecto.Query
  alias CompassAdmin.Repo
  alias CompassAdmin.User

  def init(options), do: options

  def call(%Plug.Conn{} = conn, opts) do
    verify_access!(conn, opts)
  end

  defp verify_access!(conn, _opts) do
    session = conn.cookies["session"]

    case Redix.command(:redix, ["GET", "https://#{conn.host}:session:#{session}"]) do
      {:ok, session_data} when session_data != nil ->
        %{"warden.user.user.key" => [[id], parted_crypted_pass]} = ExMarshal.decode(session_data)
        user = Repo.one(from(u in User, where: u.id == ^id))

        if user && String.slice(user.encrypted_password, 0..28) == parted_crypted_pass &&
             user.role_level > User.super_role() do
          conn
        else
          conn
          |> auth_error()
          |> halt()
        end

      _ ->
        conn
        |> auth_error()
        |> halt()
    end
  end

  defp auth_error(conn) do
    body = Jason.encode!(%{message: "Unauthorized"})
    send_resp(conn, 401, body)
  end
end
