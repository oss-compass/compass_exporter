defmodule CompassAdmin.LoginBind do
  use Ecto.Schema

  alias CompassAdmin.User

  schema "login_binds" do
    field(:provider, :string)
    field(:account, :string)
    field(:nickname, :string)
    field(:avatar_url, :string)
    field(:uid, :string)
    field(:provider_id, :string)
    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)

    belongs_to :user, User
  end
end
