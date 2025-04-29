defmodule Repo.User do
  use Repo.Schema

  schema "users" do
    field :rev,             :integer, default: 1
    field :username,        Repo.Types.StringyTrimmedLower
    field :name,            Repo.Types.StringyTrimmed
    field :email,           Repo.Types.StringyTrimmedLower
    field :phone,           Repo.Types.StringyTrimmedLower
    field :location,        Repo.Types.StringyTrimmed
    field :department,      Repo.Types.StringyTrimmed
    field :job_title,       Repo.Types.StringyTrimmed
    field :is_blocked,      :boolean, default: false
    field :is_deleted,      :boolean, default: false
    field :is_office_manager, :boolean, default: false
    belongs_to :supervisor, Repo.User
    many_to_many :groups,   Repo.Group, unique: true, on_replace: :delete,
                            join_through: "user_group_membership",
                            join_keys: [user_id: :id, group_id: :id]
    many_to_many :teams,    Repo.Team, unique: true, on_replace: :delete,
                            join_through: "user_team_membership",
                            join_keys: [user_id: :id, team_id: :id]
    has_many :highlights,   Repo.HighlightLink, on_replace: :delete
    has_many :projects,     Repo.ProjectLink, on_replace: :delete
    belongs_to :office,     Repo.Office
    belongs_to :project,    Repo.Project, foreign_key: :assigned_to
    belongs_to :role,       Repo.Role
    has_many :sessions,     Repo.Session, on_delete: :delete_all

    field :hired_at,        :naive_datetime
    field :fired_at,        :naive_datetime

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
      |> require_presence(~w(username)a)
      |> check_constraints([
        email: "email_can_not_be_empty",
        phone: "phone_can_not_be_empty",
        username: "username_can_not_be_empty",
      ])
      |> check_foreign_constraints([
        project_id: "users_assigned_to_fkey",
        office_id: "users_office_id_fkey",
        role_id: "users_role_id_fkey",
        supervisor_id: "users_supervisor_id_fkey",
      ])
      |> unique_constraints([
        email: "users_email_ult_index",
        phone: "users_phone_ult_index",
        username: "users_username_index",
        username: "users_username_ult_index",
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence(~w(username)a)
      |> check_constraints([
        email: "email_can_not_be_empty",
        phone: "phone_can_not_be_empty",
        username: "username_can_not_be_empty",
      ])
      |> check_foreign_constraints([
        project_id: "users_assigned_to_fkey",
        office_id: "users_office_id_fkey",
        role_id: "users_role_id_fkey",
        supervisor_id: "users_supervisor_id_fkey",
      ])
      |> unique_constraints([
        email: "users_email_ult_index",
        phone: "users_phone_ult_index",
        username: "users_username_index",
        username: "users_username_ult_index",
      ])
  end

  # ----------------------------------------------------------------------------

end
