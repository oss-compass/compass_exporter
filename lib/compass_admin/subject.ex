defmodule CompassAdmin.Subject do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subjects" do
    field(:label, :string)
    field(:level, :string)
    field(:status, :string)
    field(:count, :integer)
    field(:status_updated_at, :utc_datetime)
    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
    field(:collect_at, :utc_datetime)
    field(:complete_at, :utc_datetime)
  end

  @doc false
  def changeset(subject, attrs) do
    subject
    |> cast(attrs, [:label, :level, :status])
    |> validate_required([:label, :level, :status])
  end
end
