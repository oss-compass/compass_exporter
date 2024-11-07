defmodule CompassAdmin.User do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias CompassAdmin.Repo
  alias CompassAdmin.User
  alias CompassAdmin.LoginBind

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
    field(:role_level, :integer)
    has_many :login_binds, LoginBind
  end

  def find(id, opts \\ []) do
    if id != nil do
      preloads = Keyword.get(opts, :preloads, [])

      Repo.one(from(u in User, where: u.id == ^id))
      |> Repo.preload(preloads)
    end
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  def normal_role, do: 3

  def community_role, do: 4

  def frontend_dev_role, do: 5

  def model_dev_role, do: 6

  def backend_dev_role, do: 7

  def super_role, do: 10

  def admin_role, do: 65535

  def is_admin?(user), do: user.role_level >= admin_role()
end
