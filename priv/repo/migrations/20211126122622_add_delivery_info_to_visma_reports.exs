defmodule Repo.Migrations.AddDeliveryInfoToVismaReports do
  use Ecto.Migration

  def change do

    alter table("visma_reports") do
      add :delivery_task_id, :string
      add :delivery_data,   :map
      add :delivery_status, :string # :created, :running, :stopped, :completed, :error, :scheduled
      add :delivered_at,    :naive_datetime
    end

  end
end
