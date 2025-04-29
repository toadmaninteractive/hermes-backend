defmodule Repo do

  @app :hermes

  use Ecto.Repo, otp_app: @app, adapter: Ecto.Adapters.Postgres

  # ----------------------------------------------------------------------------
  # migrations
  # ----------------------------------------------------------------------------

  def migrate() do
    {:ok, _, _} = Ecto.Migrator.with_repo(__MODULE__, &Ecto.Migrator.run(&1, :up, all: true))
  end

  def rollback() do
    {:ok, _, _} = Ecto.Migrator.with_repo(__MODULE__, &Ecto.Migrator.run(&1, :down, step: 1))
  end

  def seed(env) when is_atom(env) do
  end

  # ----------------------------------------------------------------------------
  # notifications
  # ----------------------------------------------------------------------------

  def listen(channel) do
    with {:ok, pid} <- Postgrex.Notifications.start_link(__MODULE__.config()),
         {:ok, ref} <- Postgrex.Notifications.listen(pid, channel) do
      {:ok, pid, ref}
    end
  end

  # ----------------------------------------------------------------------------
  # helpers
  # ----------------------------------------------------------------------------

end
