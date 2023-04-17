defmodule CompassAdmin.Repo do
  use Ecto.Repo,
    otp_app: :compass_admin,
    adapter: Ecto.Adapters.MyXQL
end
