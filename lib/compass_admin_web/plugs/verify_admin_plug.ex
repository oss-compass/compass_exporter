defmodule CompassAdminWeb.Plugs.VerifyAdminPlug do
  import Plug.Conn

  alias CompassAdmin.User
  alias CompassAdmin.RiakPool

  @bucket "sessions"

  def init(options), do: options

  def call(%Plug.Conn{} = conn, opts) do
    verify_access!(conn, opts)
  end

  defp verify_access!(conn, _opts) do
    session = conn.cookies["session"]
    with session_data <- Riak.find(RiakPool.conn, @bucket, "https://#{conn.host}:session:#{session}"),
         true <- session_data != nil,
           %{
             "expiry" => expiry,
             "timestamp" => timestamp,
             "data" => %{ "warden.user.user.key" => [[id], parted_crypted_pass] }
           } <- session_data.data |> Jason.decode!() |> Jason.decode!(),
          true <- (timestamp + expiry) > Timex.to_unix(Timex.now),
          user <- User.find(id),
          true <- (user && String.slice(user.encrypted_password, 0..28) == parted_crypted_pass) do
      conn
      |> put_session(:current_user, user)
    else
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
