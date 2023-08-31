defmodule CompassAdmin.LabModel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_models" do
    field(:name, :string)
    field(:user_id, :integer)
    field(:dimension, :integer)
    field(:is_general, :boolean)
    field(:is_public, :boolean)
    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
    field(:default_version_id, :integer)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
