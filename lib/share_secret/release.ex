defmodule ShareSecret.Release do
  @app :share_secret

  def create do
    for repo <- repos() do
      case repo.__adapter__.storage_up(repo.config) do
        :ok ->
          IO.inspect("The database for #{inspect(repo)} has been created")

        {:error, :already_up} ->
          IO.inspect("The database for #{inspect(repo)} has already been created")

        {:error, term} when is_binary(term) ->
          IO.inspect("The database for #{inspect(repo)} couldn't be created: #{term}")

        {:error, term} ->
          IO.inspect("The database for #{inspect(repo)} couldn't be created: #{inspect(term)}")
      end
    end
  end

  def migrate do
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end
end
