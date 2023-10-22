defmodule ShareSecret.Secrets.Secret do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "secrets" do
    field :secret, :string
    field :expires_at, :utc_datetime

    timestamps updated_at: false
  end

  @required_fields ~w(secret expires_at)a

  @doc false
  def changeset(secret, attrs) do
    secret
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
  end
end
