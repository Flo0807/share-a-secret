defmodule ShareSecret.Repo do
  use Ecto.Repo,
    otp_app: :share_secret,
    adapter: Ecto.Adapters.Postgres
end
