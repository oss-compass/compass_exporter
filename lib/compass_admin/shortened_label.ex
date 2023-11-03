defmodule CompassAdmin.ShortenedLabel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "shortened_labels" do
    field(:label, :string)
    field(:short_code, :string)
    field(:level, :string)
    field(:created_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
  end

  @doc false
  def changeset(shortened_label, attrs) do
    shortened_label
    |> cast(attrs, [:label, :short_code, :level])
    |> validate_required([:label, :short_code, :level])
  end
end
