defmodule ShareSecret.Repo.Migrations.CreateSecrets do
  use Ecto.Migration

  def change do
    create table(:secrets, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :secret, :text, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(updated_at: false)
    end
  end
end
