defmodule Repo.VismaReport do
  use Repo.Schema

  schema "visma_reports" do
    # field :rev,             :integer, default: 1
    belongs_to :office,     Repo.Office
    field :office_name,     Repo.Types.StringyTrimmed
    field :year,            :integer
    field :month,           :integer
    field :comment,         Repo.Types.StringyTrimmed, default: ""
    field :report,          {:array, :map}
    field :omit_ids,        {:array, :integer} #, default: []
    field :omit_uids,       {:array, :string} #, default: []
    belongs_to :creator,    Repo.User, foreign_key: :created_by
    field :created_by_username, :string
    field :created_by_name, :string
    belongs_to :updator,    Repo.User, foreign_key: :updated_by
    field :updated_by_username, :string
    field :updated_by_name, :string

    field :delivery_task_id, :string
    field :delivery_data,   :map
    field :delivery_status, Ecto.Enum, values: [:created, :running, :stopped, :completed, :error, :scheduled]
    field :delivered_at,    :naive_datetime

    timestamps()
  end

  # ----------------------------------------------------------------------------
  # api
  # ----------------------------------------------------------------------------

  use Repo.Entity, repo: Repo

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

  @doc false
  def insert_changeset(attrs) do
    import Ecto.Changeset
    %__MODULE__{}
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [nil, ""])
      |> require_presence([:office_id, :year, :month])
      |> require_presence([:office_name, :created_by_username, :created_by_name])
      |> require_presence([:report])
      |> check_constraints([
      ])
      |> check_foreign_constraints([
        office_id: "visma_reports_office_id_fkey",
        created_by: "visma_reports_created_by_fkey",
      ])
      |> unique_constraints([
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence([:updated_by_username, :updated_by_name])
      |> check_constraints([
      ])
      |> check_foreign_constraints([
        office_id: "visma_reports_office_id_fkey",
        updated_by: "visma_reports_updated_by_fkey",
      ])
      |> unique_constraints([
      ])
  end

  # ----------------------------------------------------------------------------

end
