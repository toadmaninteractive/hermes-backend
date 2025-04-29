defmodule Repo.History do
  use Repo.Schema

  schema "action_history" do
    field :actor,           Ecto.Enum, values: ~w(user robot anonymous)a
    field :actor_id,        :integer
    field :actor_name,      :string
    field :actor_username,  :string
    field :entity,          Ecto.Enum, values: ~w(auth session settings user group group_membership country role office project report team team_membership timecell highlight project_highlight_membership project_membership)a
    field :entity_id,       :integer
    field :entity_param,    :string
    field :operation,       Ecto.Enum, values: ~w(create read update delete undelete block unblock login logout allocate deallocate protect unprotect absence download)a
    field :is_bulk,         :boolean, default: false
    field :properties,      :map, default: %{}
    field :result,          :boolean, default: false
    field :comment,         :string

    timestamps([updated_at: false] ++ @timestamps_opts)
  end

  # ----------------------------------------------------------------------------
  # api
  # ----------------------------------------------------------------------------

  use Repo.Entity, repo: Repo

  def get_ids_for_year_month_day_employee(entity, year, month, day, user_id) when is_atom(entity) and is_integer(year) and is_integer(month) and is_integer(day) and is_integer(user_id) do
    %Postgrex.Result{rows: rows} = Repo.query!("SELECT h.id FROM action_history h WHERE h.entity = '#{entity}' AND (h.properties @? '\$ ? (@.when.year == #{year} && @.when.month == #{month} && @.when.days == #{day} && @.affects.id == #{user_id})')", [])
    rows |> Enum.map(&List.first/1) |> Enum.uniq()
  end

  def get_ids_for_year_month_employees(entity, year, month, user_ids) when is_atom(entity) and is_integer(year) and is_integer(month) and is_list(user_ids) do
    ids = user_ids |> Enum.map(& to_string(&1)) |> Enum.join(",")
    %Postgrex.Result{rows: rows} = Repo.query!("SELECT h.id FROM action_history h, json_array_elements((h.properties->'affects')::json) affects WHERE h.entity = '#{entity}' AND (h.properties @? '\$.when ? (@.year == #{year} && @.month == #{month})') AND (affects->>'id')::bigint IN (#{ids})", [])
    rows |> Enum.map(&List.first/1) |> Enum.uniq()
  end

  def get_ids_for_year_month_project(entity, year, month, project_id) when is_atom(entity) and is_integer(year) and is_integer(month) and is_integer(project_id) do
    # %Postgrex.Result{rows: rows} = Repo.query!("SELECT h.id FROM action_history h, json_array_elements((h.properties->'affects')::json) affects INNER JOIN users u ON u.id = (affects->>'id')::bigint WHERE h.entity = $1 AND (h.properties @? '\$.when ? (@.year == #{year} && @.month == #{month})') AND u.assigned_to = $2", [to_string(entity), project_id])
    %Postgrex.Result{rows: rows} = Repo.query!("SELECT h.id FROM action_history h WHERE h.entity = $1 AND (h.properties @? '\$ ? (@.when.year == #{year} && @.when.month == #{month}).data.project.id ? (@ == #{project_id})')", [to_string(entity)])
    rows |> Enum.map(&List.first/1) |> Enum.uniq()
  end

  def get_ids_for_year_month_office(entity, year, month, office_id) when is_atom(entity) and is_integer(year) and is_integer(month) and is_integer(office_id) do
    %Postgrex.Result{rows: rows} = Repo.query!("SELECT h.id FROM action_history h, json_array_elements((h.properties->'affects')::json) affects INNER JOIN users u ON u.id = (affects->>'id')::bigint WHERE h.entity = $1 AND (h.properties @? '\$.when ? (@.year == #{year} && @.month == #{month})') AND u.office_id = $2", [to_string(entity), office_id])
    rows |> Enum.map(&List.first/1) |> Enum.uniq()
  end

  def get_ids_for_year_month_team(entity, year, month, team_id) when is_atom(entity) and is_integer(year) and is_integer(month) and is_integer(team_id) do
    %Postgrex.Result{rows: rows} = Repo.query!("SELECT h.id FROM action_history h, json_array_elements((h.properties->'affects')::json) affects , user_team_membership utm WHERE utm.user_id = (affects->>'id')::bigint AND h.entity = $1 AND (h.properties @? '\$.when ? (@.year == #{year} && @.month == #{month})') AND utm.team_id = $2", [to_string(entity), team_id])
    rows |> Enum.map(&List.first/1) |> Enum.uniq()
  end

  def all_for_employee(employee_id) when is_integer(employee_id) do
    query = from x in __MODULE__,
      join: u in Repo.User, on: fragment("?.properties->'affects' @> json_build_array(json_build_object('id', ?.id))::jsonb", x, u),
      where: x.entity == :user and x.operation == :update,
      where: u.id == ^employee_id
   query
  end

  def all_for_office(office_id) when is_integer(office_id) do
    query = from x in __MODULE__,
      join: u in Repo.User, on: fragment("?.properties->'affects' @> json_build_array(json_build_object('id', ?.id))::jsonb", x, u),
      where: x.entity == :user and x.operation == :update,
      where: u.office_id == ^office_id
   query
  end

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

  @doc false
  def insert_changeset(attrs) do
    import Ecto.Changeset
    %__MODULE__{}
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [nil, ""])
      |> require_presence(~w(actor entity operation)a)
      |> check_constraints([
      ])
      |> check_foreign_constraints([
      ])
      |> unique_constraints([
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence(~w(actor entity operation)a)
      |> check_constraints([
      ])
      |> check_foreign_constraints([
      ])
      |> unique_constraints([
      ])
  end

  # ----------------------------------------------------------------------------

end
