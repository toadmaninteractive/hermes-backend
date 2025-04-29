defmodule Repo.Project do
  use Repo.Schema

  schema "projects" do
    field :rev,             :integer, default: 1
    field :title,           :string
    field :key,             :string
    field :color,           :string
    field :finance_code,    :string
    field :invoiceable,     :boolean, default: false
    field :is_archived,     :boolean, default: false
    field :task_code,       Ecto.Enum, values: ~w(project cont_dev rnd)a
    belongs_to :supervisor, Repo.User
    belongs_to :leading_office, Repo.Office
    has_many :users,        Repo.ProjectLink, on_replace: :delete
    field :started_at,      :naive_datetime
    field :finished_at,     :naive_datetime

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
      |> require_presence(~w(title key leading_office_id finance_code task_code)a)
      |> check_constraints([
        key: "key_can_not_be_empty",
        title: "title_can_not_be_empty",
        finance_code: "finance_code_can_not_be_empty",
        task_code: "task_code_can_not_be_empty",
      ])
      |> check_foreign_constraints([
        leading_office_id: "projects_leading_office_id_fkey",
        supervisor_id: "projects_supervisor_id_fkey",
      ])
      |> unique_constraints([
        key: "projects_key_ult_index",
        title: "projects_title_ult_index",
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence(~w(title key leading_office_id finance_code task_code)a)
      |> check_constraints([
        key: "key_can_not_be_empty",
        title: "title_can_not_be_empty",
        finance_code: "finance_code_can_not_be_empty",
        task_code: "task_code_can_not_be_empty",
      ])
      |> check_foreign_constraints([
        leading_office_id: "projects_leading_office_id_fkey",
        supervisor_id: "projects_supervisor_id_fkey",
      ])
      |> unique_constraints([
        key: "projects_key_ult_index",
        title: "projects_title_ult_index",
      ])
  end

  # ----------------------------------------------------------------------------

end
