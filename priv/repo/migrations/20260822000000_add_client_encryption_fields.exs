defmodule ShareSecret.Repo.Migrations.AddClientEncryptionFields do
  use Ecto.Migration

  def change do
    alter table(:secrets) do
      modify :secret, :text, null: true, from: {:text, null: false}
      add :format_version, :smallint, null: false, default: 0
      add :encrypted_payload, :binary
      add :claim_verifier, :binary
    end

    create index(:secrets, [:expires_at])

    create constraint(:secrets, :secrets_supported_format, check: "format_version IN (0, 1)")

    create constraint(:secrets, :secrets_versioned_columns,
             check: """
             (format_version = 0 AND secret IS NOT NULL AND encrypted_payload IS NULL AND claim_verifier IS NULL)
             OR
             (format_version = 1 AND secret IS NULL AND encrypted_payload IS NOT NULL AND claim_verifier IS NOT NULL)
             """
           )

    create constraint(:secrets, :secrets_v1_envelope,
             check: """
             format_version <> 1 OR (
               octet_length(encrypted_payload) BETWEEN 30 AND 65565
               AND substring(encrypted_payload FROM 1 FOR 1) = decode('01', 'hex')
               AND octet_length(claim_verifier) = 32
             )
             """
           )

    create constraint(:secrets, :secrets_positive_lifetime, check: "expires_at > inserted_at")
  end
end
