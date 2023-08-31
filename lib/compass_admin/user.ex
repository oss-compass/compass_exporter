defmodule CompassAdmin.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:encrypted_password, :string)
    field(:reset_password_token, :string)
    field(:reset_password_sent_at, :utc_datetime)
    field(:sign_in_count, :integer)
    field(:current_sign_in_at, :utc_datetime)
    field(:last_sign_in_at, :utc_datetime)
    field(:current_sign_in_ip, :string)
    field(:last_sign_in_ip, :string)
    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
    field(:anonymous, :boolean)
    field(:email_verification_token, :string)
    field(:email_verification_sent_at, :utc_datetime)
    field(:name, :string)
    field(:language, :string)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
