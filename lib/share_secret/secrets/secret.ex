defmodule ShareSecret.Secrets.Secret do
  @moduledoc """
  The secret schema.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "secrets" do
    field :secret, :string, redact: true
    field :format_version, :integer, default: 0
    field :encrypted_payload, :binary, redact: true
    field :claim_verifier, :binary, redact: true
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

  @doc false
  def encrypted_changeset(secret, attrs) do
    secret
    |> cast(attrs, [:encrypted_payload, :claim_verifier])
    |> validate_required([
      :id,
      :format_version,
      :encrypted_payload,
      :claim_verifier,
      :expires_at
    ])
    |> validate_binary_size(:encrypted_payload, 30, 65_565)
    |> validate_binary_size(:claim_verifier, 32, 32)
    |> unique_constraint(:id, name: :secrets_pkey)
    |> check_constraint(:format_version, name: :secrets_supported_format)
    |> check_constraint(:format_version, name: :secrets_versioned_columns)
    |> check_constraint(:encrypted_payload, name: :secrets_v1_envelope)
    |> check_constraint(:expires_at, name: :secrets_positive_lifetime)
  end

  defp validate_binary_size(changeset, field, minimum, maximum) do
    validate_change(changeset, field, fn ^field, value ->
      size = byte_size(value)

      if size in minimum..maximum do
        []
      else
        [{field, "has an invalid byte size"}]
      end
    end)
  end
end
