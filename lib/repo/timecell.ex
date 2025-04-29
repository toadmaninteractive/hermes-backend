defmodule Repo.TimeCell do
  use Repo.Schema

  schema "timecells" do
    field :slot_date,       :naive_datetime
    field :time_off,        Ecto.Enum, values: ~w(vacation paid_vacation unpaid_vacation absence travel vab sick unpaid_sick holiday empty parental_leave maternity_leave time_off temp_leave)a
    field :is_protected,    :boolean, default: false
    field :set_by,          :integer
    belongs_to :user,       Repo.User
    belongs_to :project,    Repo.Project
    field :comment,              :string

    field :personnel_name,        :string, virtual: true
    field :personnel_username,    :string, virtual: true
    field :project_name,          :string, virtual: true
    field :project_finance_code,  :string, virtual: true
    field :project_invoiceable,   :boolean, virtual: true
    field :project_task_code,     :string, virtual: true
    field :office_name,           :string, virtual: true
    field :office_country_alpha2, :string, virtual: true
    field :role,                  :string, virtual: true
    field :role_id,               :integer, virtual: true
    field :role_title,            :string, virtual: true

    timestamps()
  end

  # ----------------------------------------------------------------------------
  # api
  # ----------------------------------------------------------------------------

  use Repo.Entity, repo: Repo

  import Ecto.Query

  # ----------------------------------------------------------------------------

  def all_for_year_month(year, month, criteria \\ []) do
    query = from x in filter(criteria),
      where: fragment("extract(year from slot_date) = ? and extract(month from slot_date) = ?", ^year, ^month),
      order_by: [:slot_date, :user_id],
      select_merge: %{
      }
    query |> Repo.all
  end

  def all_for_date_range(date1, date2, criteria \\ []) do
    query = from x in filter(criteria),
      where: fragment("? between ? and ?", x.slot_date, ^date1, ^date2),
      # where: x.user_id == 1123,
      join: u in Repo.User, on: x.user_id == u.id,
      left_join: p in Repo.Project, on: x.project_id == p.id,
      left_join: o in Repo.Office, on: u.office_id == o.id,
      join: c in Repo.Country, on: o.country_id == c.id,
      left_join: r in Repo.Role, on: u.role_id == r.id,
      order_by: [:slot_date],
      select_merge: %{
        personnel_name: u.name,
        personnel_username: u.username,
        project_name: p.title,
        project_invoiceable: p.invoiceable,
        project_finance_code: p.finance_code,
        project_task_code: p.task_code,
        office_country_alpha2: c.alpha2,
        role: r.code
      }
    query |> Repo.all
  end

  def all_for_date_range_office(date1, date2, office_id) do
    query = from x in filter([]),
      where: fragment("? between ? and ?", x.slot_date, ^date1, ^date2),
      join: u in Repo.User, on: x.user_id == u.id,
      left_join: p in Repo.Project, on: x.project_id == p.id,
      left_join: o in Repo.Office, on: u.office_id == o.id,
      join: c in Repo.Country, on: o.country_id == c.id,
      left_join: r in Repo.Role, on: u.role_id == r.id,
      where: u.office_id == ^office_id,
      order_by: [u.name, :slot_date],
      select_merge: %{
        personnel_name: u.name,
        personnel_username: u.username,
        project_name: p.title,
        project_invoiceable: p.invoiceable,
        project_finance_code: p.finance_code,
        project_task_code: p.task_code,
        office_name: o.name,
        office_country_alpha2: c.alpha2,
        role: r.code,
        role_id: r.id,
        role_title: r.title
      }
    query |> Repo.all
  end

  # def with_year_month(query, year, month) when is_integer(year) and is_integer(month) do
  #   query
  #     |> where([x], fragment("extract(year from slot_date) = ? and extract(month from slot_date) = ?", ^year, ^month))
  # end

  # def with_employees(query, user_ids) when is_list(user_ids) do
  #   query
  #     |> where([x], x.id in ^user_ids)
  # end

  # def with_project(query, project_id) when is_integer(project_id) do
  #   query
  #     |> join(:inner, [x], u in Repo.User, on: x.user_id == u.id) |> where([x, u], u.assigned_to == ^project_id)
  # end

  # def with_office(query, office_id) when is_integer(office_id) do
  #   query
  #     |> join(:inner, [x], u in Repo.User, on: x.user_id == u.id) |> where([x, u], u.office_id == ^office_id)
  # end

  # def with_team(query, team_id) when is_integer(team_id) do
  #   query
  #     |> join(:inner, [x], utm in fragment("user_team_membership"), on: x.user_id == utm.user_id) |> where([x, utm], utm.team_id == ^team_id)
  # end

  def tune(query, {:ids, ids}) when is_list(ids) do
    from x in query, where: x.id in ^ids
  end
  def tune(query, {:month, year, month}) when is_integer(year) and is_integer(month) do
    from x in query, where: fragment("extract(year from ?) = ? and extract(month from ?) = ?", x.slot_date, ^year, x.slot_date, ^month)
  end
  def tune(query, {:employees, user_ids}) when is_list(user_ids) do
    from x in query, join: u in Repo.User, on: x.user_id == u.id, where: u.id in ^user_ids
  end
  def tune(query, {:projects, project_ids}) when is_list(project_ids) do
    from x in query, join: u in Repo.User, on: x.user_id == u.id, where: u.assigned_to in ^project_ids
  end
  def tune(query, {:offices, office_ids}) when is_list(office_ids) do
    from x in query, join: u in Repo.User, on: x.user_id == u.id, where: u.office_id in ^office_ids
  end
  def tune(query, {:teams, team_ids}) when is_list(team_ids) do
    from x in query, join: utm in fragment("user_team_membership"), on: x.user_id == utm.user_id, where: utm.team_id in ^team_ids
  end
  def tune(query, {:custom, criteria}) when is_list(criteria) do
    filter(criteria, query)
  end
  def tune(query, :not_empty) do
    from x in query, where: (not is_nil(x.project_id) or not is_nil(x.time_off))
  end
  def tune(query, :self) do
    from x in query, join: x0 in __MODULE__, on: x0.id == x.id
  end
  def tune(query, criteria) when is_list(criteria) do
    criteria
      |> Enum.reduce(query, fn criteria, acc -> acc |> tune(criteria) end)
  end

  def for_update(fields \\ []) when is_list(fields) do
    from x in __MODULE__,
      join: x0 in __MODULE__, on: x0.id == x.id,
      select: [x.id, x.slot_date, x.user_id, x0.project_id, x.project_id, x0.time_off, x.time_off, x0.is_protected, x.is_protected]
  end

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

  @doc false
  def insert_changeset(attrs) do
    import Ecto.Changeset
    %__MODULE__{}
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [nil, ""])
      |> require_presence(~w(slot_date user_id)a)
      |> check_constraints([
      ])
      |> check_foreign_constraints([
        project_id: "dayslots_project_id_fkey",
        user_id: "dayslots_user_id_fkey",
      ])
      |> unique_constraints([
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence(~w(slot_date user_id)a)
      |> check_constraints([
      ])
      |> check_foreign_constraints([
        project_id: "dayslots_project_id_fkey",
        user_id: "dayslots_user_id_fkey",
      ])
      |> unique_constraints([
      ])
  end

  # ----------------------------------------------------------------------------

end
