defmodule Hermes do
  @moduledoc """
  Documentation for `Hermes`.
  """

  alias Repo.{Country, Group, Highlight, HighlightLink, History, Office, OfficeRoleLink, Project, ProjectLink, Role, Session, Setting, Team, TeamManagerLink, TimeCell, User, VismaReport}

  # ----------------------------------------------------------------------------

  @spec get_settings() :: Map.t()
  @doc ~S"""
  Returns map of all settings.

  ## Examples

      iex> settings = Hermes.get_settings()
      iex> %{personnel_session_duration: personnel_session_duration} = settings
      iex> is_integer(personnel_session_duration)

  """
  def get_settings() do
    Setting.to_map
  end

  @spec update_settings!(Map.t()) :: Map.t()
  @doc ~S"""
  Updates settings with a with specified fields.

  ## Examples

      iex> Hermes.update_settings!(%{personnel_session_duration: 123})
      %{personnel_session_duration: 123}

      # iex> Hermes.update_settings!(%{foo: :bar})
      # ** (DataProtocol.NotFoundError) NotFoundError

  """
  def update_settings!(patch) when is_map(patch) do
    Setting.update(patch)
    get_settings()
  end

  # ----------------------------------------------------------------------------

  @spec get_countries(Keyword.t()) :: [DbProtocol.Country.t()]
  @doc ~S"""
  Returns list of all countries.

  ## Examples

      iex> [item | _] = Hermes.get_countries()
      iex> is_struct(item, DbProtocol.Country)

      iex> [item] = Hermes.get_countries(alpha2: "ru")
      iex> is_struct(item, DbProtocol.Country)
      iex> %{id: 643, alpha2: "ru", alpha3: "rus", name: "Russian Federation"} = item

  """
  def get_countries(criteria \\ [order_by: :name]) when is_list(criteria) do
    criteria
      |> Country.all
      |> DbProtocol.Impl.to_country
  end

  @spec get_country!(Integer.t()) :: DbProtocol.Country.t()
  @doc ~S"""
  Returns an existing country by id.

  ## Examples

      iex> item = Hermes.get_country!(643)
      iex> is_struct(item, DbProtocol.Country)
      iex> %{id: 643, alpha2: "ru", alpha3: "rus", name: "Russian Federation"} = item

      iex> Hermes.get_country!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_country!(id) when is_integer(id) do
    [id: id]
      |> Country.one!
      |> DbProtocol.Impl.to_country
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  # ----------------------------------------------------------------------------

  @spec get_employee!(Integer.t()) :: DbProtocol.PersonnelAccount.t()
  @doc ~S"""
  Returns an existing employee by id.

  ## Examples

      iex> item = Hermes.get_employee!(178)
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> %{id: _, name: "Vasya Pupkin", username: "vasya.pupkin"} = item

      iex> Hermes.get_employee!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_employee!(id) when is_integer(id) do
    [id: id]
      |> User.one!
      |> DbProtocol.Impl.to_personnel_account
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec get_employee_by_username!(String.t()) :: DbProtocol.PersonnelAccount.t()
  @doc ~S"""
  Returns an existing employee by username.

  ## Examples

      iex> item = Hermes.get_employee_by_username!("vasya.pupkin")
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> %{id: _, name: "Vasya Pupkin", username: "vasya.pupkin"} = item

      iex> Hermes.get_employee_by_username!("bebebe")
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_employee_by_username!(username) when is_binary(username) do
    [username: username]
      |> User.one!
      |> DbProtocol.Impl.to_personnel_account
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec get_employees_by_office(Integer.t()) :: [DbProtocol.PersonnelAccount.t()]
  @doc ~S"""
  Returns a list of employees assigned to an office by office id.

  ## Examples

      iex> items = [item | _] = Hermes.get_employees_by_office(4)
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> items |> Enum.any?(& &1.username === "vasya.pupkin")

      iex> Hermes.get_employees_by_office(-1)
      []

  """
  def get_employees_by_office(office_id) when is_integer(office_id) do
    get_personnels(office_id: office_id, order_by: :name)
  end

  @spec get_employees_by_project(Integer.t(), NaiveDateTime.t(), NaiveDateTime.t()) :: [DbProtocol.PersonnelAccount.t()]
  @doc ~S"""
  Returns a list of employees assigned to a project within specified date range by project id.

  ## Examples

      iex> items = Hermes.get_employees_by_project(27, NaiveDateTime.new!(2021, 7, 1, 0, 0, 0), NaiveDateTime.new!(2021, 8, 1, 0, 0, 0))
      iex> [item | _] = items
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> items |> Enum.any?(& &1.username === "vasya.pupkin")

      iex> Hermes.get_employees_by_project(-1, NaiveDateTime.new!(2021, 7, 1, 0, 0, 0), NaiveDateTime.new!(2021, 8, 1, 0, 0, 0))
      []

  """
  def get_employees_by_project(project_id, date1, date2) when is_integer(project_id) and is_struct(date1, NaiveDateTime) and is_struct(date2, NaiveDateTime) do
    import Ecto.Query, only: [from: 2]
    # fetch users that _were_ assigned to the project within the date range
    assigned_on_month = (from x in TimeCell,
        where: fragment("? between ? and ?", x.slot_date, ^date1, ^date2),
        where: x.project_id == ^project_id,
        distinct: [:user_id])
      |> Repo.all
      |> Enum.map(& &1.user_id)
    # fetch users that _are_ assigned to the project
    assigned_now = (from u in User,
        where: u.assigned_to == ^project_id,
        distinct: [:id])
      |> Repo.all
      |> Enum.map(& &1.id)
    ids = (assigned_on_month ++ assigned_now)
      |> Enum.uniq
    get_personnels(id: ids, order_by: [:name])
  end

  def get_employees_linked_to_project(project_id, date1, date2) when is_integer(project_id) and is_struct(date1, NaiveDateTime) and is_struct(date2, NaiveDateTime) do
    import Ecto.Query, only: [from: 2]
    linked_to = Project.one!(id: project_id, preload: [:users]).users
      |> Enum.filter(& Date.compare(Date.beginning_of_month(date1), Date.beginning_of_month(&1.created_at)) != :lt)
      |> Enum.map(& &1.user_id)
    ids = linked_to
      |> Enum.uniq
    get_personnels(id: ids, order_by: [:name])
  end

  @spec get_employees_by_team(Integer.t()) :: [DbProtocol.PersonnelAccount.t()]
  @doc ~S"""
  Returns a list of employees of a team by team id.

  ## Examples

      iex> items = [item | _] = Hermes.get_employees_by_team(1)
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> items |> Enum.any?(& &1.username === "vasya.pupkin")

      iex> Hermes.get_employees_by_team(-1)
      []

  """
  def get_employees_by_team(team_id) when is_integer(team_id) do
    ids = Team.one!(id: team_id, preload: [:users])
      |> Map.get(:users)
      |> Enum.map(& &1.id)
    get_personnels(id: ids, order_by: :name)
  rescue
    Ecto.NoResultsError -> []
  end

  @spec get_active_employees(NaiveDateTime.t(), NaiveDateTime.t()) :: [DbProtocol.PersonnelAccount.t()]

  def get_active_employees(date1, date2) when is_struct(date1, NaiveDateTime) and is_struct(date2, NaiveDateTime) do
    import Ecto.Query, only: [from: 2]
    ids = (
      from u in User,
      where: fragment("(case when ? is null then true else ? <= ? end) AND (case when ? is null then true else ? >= ? end)", u.hired_at, u.hired_at, ^date2, u.fired_at, u.fired_at, ^date1),
      distinct: [:id]
    )
    |> Repo.all
    |> Enum.map(& &1.id)
    get_personnels(id: ids, order_by: [:name])
  end

  @spec allocate_employee!(Integer.t(), Integer.t() | nil) :: DbProtocol.PersonnelAccount.t()
  @doc ~S"""
  Assigns a project by id to an existing employee by id. Returns the employee.
  Resets the assignment if `nil` is given for project id.

  ## Examples

      iex> item = Hermes.allocate_employee!(178, 27)
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> %{id: _, allocated_to_project_id: 27, allocated_to_project_name: "Hermes"} = item

      iex> item = Hermes.allocate_employee!(178, nil)
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> %{id: _, allocated_to_project_id: nil, allocated_to_project_name: nil} = item

  """
  def allocate_employee!(id, project_id) when is_integer(id) do
    case User.update(User.one!(id: id), assigned_to: project_id) do
      {:ok, record} ->
        get_employee!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  # ----------------------------------------------------------------------------

  @spec get_offices(Keyword.t()) :: [DbProtocol.Office.t()]
  @doc ~S"""
  Returns list of all offices.

  ## Examples

      iex> [item | _] = Hermes.get_offices()
      iex> is_struct(item, DbProtocol.Office)

      iex> [item] = Hermes.get_offices(name: "Main Office")
      iex> is_struct(item, DbProtocol.Office)
      iex> %{id: 4, name: "Main Office"} = item

  """
  def get_offices(criteria \\ [order_by: :name]) when is_list(criteria) do
    criteria
      |> Office.all
      |> DbProtocol.Impl.to_office
  end

  @spec get_office!(Integer.t()) :: DbProtocol.Office.t()
  @doc ~S"""
  Returns an existing office by id.

  ## Examples

      iex> item = Hermes.get_office!(4)
      iex> is_struct(item, DbProtocol.Office)
      iex> %{id: 4, name: "Main Office"} = item

      iex> Hermes.get_office!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_office!(id) when is_integer(id) do
    [id: id]
      |> Office.one!
      |> DbProtocol.Impl.to_office
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec create_office!(Map.t()) :: DbProtocol.Office.t()
  @doc ~S"""
  Creates an office with specified fields. Returns the office.

  ## Examples

      iex> item = Hermes.create_office!(%{name: "Test Office 1", country_id: 643})
      iex> is_struct(item, DbProtocol.Project)
      iex> %{id: _, name: "Test Office 1", country_name: "Russian Federation"} = item

      iex> Hermes.create_office!(%{name: "Main Office", country_id: 643})
      ** (DataProtocol.BadRequestError) BadRequestError

      iex> Hermes.create_office!(%{})
      ** (DataProtocol.BadRequestError) BadRequestError

  """
  def create_office!(fields) when is_map(fields) do
    case Office.insert(fields) do
      {:ok, record} ->
        get_office!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  end

  @spec update_office!(Integer.t(), Map.t()) :: DbProtocol.Office.t()
  @doc ~S"""
  Update an office by id with specified fields. Returns the office.

  ## Examples

      iex> item = Hermes.update_office!(4, %{name: "Test Office 11", country_id: 600})
      iex> is_struct(item, DbProtocol.Project)
      iex> %{id: _, name: "Test Office 11", country_name: "Paraguay"} = item

  """
  def update_office!(id, patch) when is_integer(id) and is_map(patch) do
    case Office.update(Office.one!(id: id), patch) do
      {:ok, record} ->
        get_office!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec delete_office!(Integer.t()) :: :ok
  @doc ~S"""
  Deletes an office by id.

  ## Examples

      iex> Hermes.delete_office!(4)
      :ok

  """
  def delete_office!(id) when is_integer(id) do
    case Office.delete_many(id: id) do
      :ok -> :ok
      {:error, :not_exists} -> raise DataProtocol.NotFoundError
    end
  end

  # ----------------------------------------------------------------------------

  @spec get_personnels(Keyword.t()) :: [DbProtocol.PersonnelAccount.t()]
  @doc ~S"""
  Returns list of all personnels.

  ## Examples

      iex> [item | _] = Hermes.get_personnels()
      iex> is_struct(item, DbProtocol.PersonnelAccount)

      iex> [item] = Hermes.get_personnels(name: "Vasya Pupkin")
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> %{id: _, name: "Vasya Pupkin", username: "vasya.pupkin"} = item

  """
  def get_personnels(criteria \\ [order_by: :name]) when is_list(criteria) do
    criteria
      |> User.all
      |> DbProtocol.Impl.to_personnel_account
  end

  @spec count_personnels(Keyword.t()) :: Integer.t()
  @doc ~S"""
  Returns amount of all personnels.

  ## Examples

      iex> n = Hermes.count_personnels()
      iex> is_integer(n) and n >= 0

  """
  def count_personnels(criteria \\ []) when is_list(criteria) do
    criteria
      |> User.count
  end

  @spec get_personnel!(Integer.t()) :: DbProtocol.PersonnelAccount.t()
  @doc ~S"""
  Returns an existing personnel by id.

  ## Examples

      iex> item = Hermes.get_personnel!(178)
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> %{id: _, name: "Vasya Pupkin", username: "vasya.pupkin"} = item

      iex> Hermes.get_personnel!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_personnel!(id) when is_integer(id) do
    [id: id]
      |> User.one!
      |> DbProtocol.Impl.to_personnel_account
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec get_personnel_by_username!(String.t()) :: DbProtocol.PersonnelAccount.t()
  @doc ~S"""
  Returns an existing personnel by the user name.

  ## Examples

      iex> item = Hermes.get_personnel_by_username!("vasya.pupkin")
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> %{id: _, name: "Vasya Pupkin", username: "vasya.pupkin"} = item

      iex> Hermes.get_personnel_by_username!("bebebe")
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_personnel_by_username!(username) when is_binary(username) do
    get_employee_by_username!(username)
  end

  @spec update_personnel!(Integer.t(), Map.t()) :: DbProtocol.PersonnelAccount.t()
  @doc ~S"""
  Update a personnel by id with specified fields. Returns the office.

  ## Examples

      iex> item = Hermes.update_personnel!(178, %{name: "Vasya Pupkin"})
      iex> is_struct(item, DbProtocol.PersonnelAccount)
      iex> %{id: _, name: "Vasya Pupkin"} = item

  """
  def update_personnel!(id, patch) when is_integer(id) and is_map(patch) do
    case User.update(User.one!(id: id), patch) do
      {:ok, record} ->
        get_personnel!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  # ----------------------------------------------------------------------------

  @spec get_personnel_groups(Keyword.t()) :: [DbProtocol.PersonnelGroup.t()]
  @doc ~S"""
  Returns list of all personnel groups.

  ## Examples

      iex> [item | _] = Hermes.get_personnel_groups()
      iex> is_struct(item, DbProtocol.PersonnelGroup)

      iex> [item] = Hermes.get_personnel_groups(name: "Admins")
      iex> is_struct(item, DbProtocol.PersonnelGroup)
      iex> %{id: 23, name: "Admins"} = item

  """
  def get_personnel_groups(criteria \\ [order_by: :name]) when is_list(criteria) do
    criteria
      |> Group.all
      |> DbProtocol.Impl.to_personnel_group
  end

  @spec count_personnel_groups(Keyword.t()) :: Integer.t()
  @doc ~S"""
  Returns amount of all personnel groups.

  ## Examples

      iex> n = Hermes.count_personnel_groups()
      iex> is_integer(n) and n >= 0

  """
  def count_personnel_groups(criteria \\ []) when is_list(criteria) do
    criteria
      |> Group.count
  end

  @spec get_personnel_group!(Integer.t()) :: DbProtocol.PersonnelGroup.t()
  @doc ~S"""
  Returns an existing personnel group by id.

  ## Examples

      iex> item = Hermes.get_personnel_group!(23)
      iex> is_struct(item, DbProtocol.PersonnelGroup)
      iex> %{id: 23, name: "Admins"} = item

      iex> Hermes.get_personnel_group!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_personnel_group!(id) when is_integer(id) do
    [id: id]
      |> Group.one!
      |> DbProtocol.Impl.to_personnel_group
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec get_personnel_group_by_name!(String.t()) :: DbProtocol.PersonnelGroup.t()
  @doc ~S"""
  Returns an existing personnel group by name.

  ## Examples

      iex> item = Hermes.get_personnel_group_by_name!("Admins")
      iex> is_struct(item, DbProtocol.PersonnelGroup)
      iex> %{id: _, name: "Admins"} = item

      iex> Hermes.get_personnel_group_by_name!("bebebe")
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_personnel_group_by_name!(name) when is_binary(name) do
    [name: name]
      |> Group.one!
      |> DbProtocol.Impl.to_personnel_group
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  # ----------------------------------------------------------------------------

  @spec get_projects(Keyword.t()) :: [DbProtocol.Project.t()]
  @doc ~S"""
  Returns list of all projects.

  ## Examples

      iex> [item | _] = Hermes.get_projects()
      iex> is_struct(item, DbProtocol.Project)

      iex> [item] = Hermes.get_projects(key: "hermes")
      iex> is_struct(item, DbProtocol.Project)
      iex> %{id: 27, key: "hermes", title: "Hermes"} = item

  """
  def get_projects(criteria \\ [order_by: :title]) when is_list(criteria) do
    criteria
      |> Project.all
      |> DbProtocol.Impl.to_project
  end

  @spec get_project!(Integer.t()) :: DbProtocol.Project.t()
  @doc ~S"""
  Returns an existing project by id.

  ## Examples

      iex> item = Hermes.get_project!(27)
      iex> is_struct(item, DbProtocol.Project)
      iex> %{id: 27, key: "hermes", title: "Hermes"} = item

      iex> Hermes.get_project!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_project!(id) when is_integer(id) do
    [id: id]
      |> Project.one!
      |> DbProtocol.Impl.to_project
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec create_project!(Map.t()) :: DbProtocol.Project.t()
  @doc ~S"""
  Creates a project with specified fields. Returns the project.

  ## Examples

      iex> item = Hermes.create_project!(%{key: "test_project_1", title: "Test Project 1", leading_office_id: 4, finance_code: "1", invoiceable: true, task_code: :rnd})
      iex> is_struct(item, DbProtocol.Project)
      iex> %{id: _, key: "test_project_1", title: "Test Project 1", leading_office_id: 4, finance_code: "1", invoiceable: true, task_code: :rnd} = item

      iex> Hermes.create_project!(%{})
      ** (DataProtocol.BadRequestError) BadRequestError

  """
  def create_project!(fields) when is_map(fields) do
    case Project.insert(fields) do
      {:ok, record} ->
        get_project!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  end

  @spec update_project!(Integer.t(), Map.t()) :: DbProtocol.Project.t()
  @doc ~S"""
  Updates a project by id with a patch record. Returns the project.

  ## Examples

      iex> item = Hermes.update_project!(27, %{title: "Updated Project"})
      iex> is_struct(item, DbProtocol.Project)
      iex> %{id: 27, title: "Updated Project", rev: 4} = item

      iex> Hermes.update_project!(-1, %{})
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def update_project!(id, patch) when is_integer(id) and is_map(patch) do
    case Project.update(Project.one!(id: id), patch) do
      {:ok, record} ->
        get_project!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec delete_project!(Integer.t()) :: :ok
  @doc ~S"""
  Deletes a project by id.

  ## Examples

      iex> Hermes.delete_project!(27)
      :ok

      iex> Hermes.delete_project!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def delete_project!(id) when is_integer(id) do
    case Project.delete_many(id: id) do
      :ok -> :ok
      {:error, :not_exists} -> raise DataProtocol.NotFoundError
    end
  end

  # ----------------------------------------------------------------------------

  @spec get_roles(Keyword.t()) :: [DbProtocol.Role.t()]
  @doc ~S"""
  Returns list of all roles.

  ## Examples

      iex> [item | _] = Hermes.get_roles()
      iex> is_struct(item, DbProtocol.Role)

      iex> [item] = Hermes.get_roles(title: "Programmer Senior")
      iex> is_struct(item, DbProtocol.Role)
      iex> %{id: 12, code: "00117", title: "Programmer Senior"} = item

  """
  def get_roles(criteria \\ [order_by: :title]) when is_list(criteria) do
    criteria
      |> Role.all
      |> DbProtocol.Impl.to_role
  end

  @spec get_role!(Integer.t()) :: DbProtocol.Role.t()
  @doc ~S"""
  Returns an existing role by id.

  ## Examples

      iex> item = Hermes.get_role!(12)
      iex> is_struct(item, DbProtocol.Role)
      iex> %{id: 12, code: "00117", title: "Programmer Senior"} = item

      iex> Hermes.get_role!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_role!(id) when is_integer(id) do
    [id: id]
      |> Role.one!
      |> DbProtocol.Impl.to_role
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec create_role!(Map.t()) :: DbProtocol.Role.t()
  @doc ~S"""
  Creates a role with specified fields. Returns the role.

  ## Examples

      iex> item = Hermes.create_role!(%{code: "test_role_1", title: "Test Role 1"})
      iex> is_struct(item, DbProtocol.Role)
      iex> %{id: _, code: "test_role_1", title: "Test Role 1"} = item

      iex> Hermes.create_role!(%{})
      ** (DataProtocol.BadRequestError) BadRequestError

  """
  def create_role!(fields) when is_map(fields) do
    case Role.insert(fields) do
      {:ok, record} ->
        get_role!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  end

  @spec update_role!(Integer.t(), Map.t()) :: DbProtocol.Role.t()
  @doc ~S"""
  Updates a role by id with a patch record. Returns the role.

  ## Examples

      iex> item = Hermes.update_role!(12, %{title: "Updated Role"})
      iex> is_struct(item, DbProtocol.Role)
      iex> %{id: 12, title: "Updated Role", rev: 2} = item

      iex> Hermes.update_role!(-1, %{})
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def update_role!(id, patch) when is_integer(id) and is_map(patch) do
    case Role.update(Role.one!(id: id), patch) do
      {:ok, record} ->
        get_role!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec delete_role!(Integer.t()) :: :ok
  @doc ~S"""
  Deletes a role by id.

  ## Examples

      iex> Hermes.delete_role!(12)
      :ok

      iex> Hermes.delete_role!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def delete_role!(id) when is_integer(id) do
    case Role.delete_many(id: id) do
      :ok -> :ok
      {:error, :not_exists} -> raise DataProtocol.NotFoundError
    end
  end

  @spec enable_role_for_office(Integer.t(), Integer.t()) :: :ok | {:error, Atom.t()}
  def enable_role_for_office(role_id, office_id) when is_integer(role_id) and is_integer(office_id) do
    case OfficeRoleLink.insert(%{office_id: office_id, role_id: role_id}) do
      {:ok, _record} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @spec disable_role_for_office(Integer.t(), Integer.t()) :: :ok | {:error, Atom.t()}
  def disable_role_for_office(role_id, office_id) when is_integer(role_id) and is_integer(office_id) do
    OfficeRoleLink.delete_many(office_id: office_id, role_id: role_id)
  end

  # ----------------------------------------------------------------------------

  @spec get_highlights(Keyword.t()) :: [DbProtocol.Highlight.t()]
  def get_highlights(criteria \\ []) when is_list(criteria) do
    criteria
      |> Highlight.all
      |> DbProtocol.Impl.to_highlight
  end

  @spec get_highlight!(Integer.t()) :: DbProtocol.Highlight.t()
  def get_highlight!(id) when is_integer(id) do
    [id: id]
      |> Highlight.one!
      |> DbProtocol.Impl.to_highlight
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec create_highlight!(Map.t()) :: DbProtocol.Highlight.t()
  def create_highlight!(fields) when is_map(fields) do
    case Highlight.insert(fields) do
      {:ok, record} ->
        get_highlight!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  end

  @spec update_highlight!(Integer.t(), Map.t()) :: DbProtocol.Highlight.t()
  def update_highlight!(id, patch) when is_integer(id) and is_map(patch) do
    case Highlight.update(Highlight.one!(id: id), patch) do
      {:ok, record} ->
        get_highlight!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec delete_highlight!(Integer.t()) :: :ok
  def delete_highlight!(id) when is_integer(id) do
    case Highlight.delete_many(id: id) do
      :ok -> :ok
      {:error, :not_exists} -> raise DataProtocol.NotFoundError
    end
  end

  @spec add_employee_project_highlight(Integer.t(), Integer.t(), Integer.t()) :: :ok | {:error, Atom.t()}
  def add_employee_project_highlight(personnel_id, project_id, highlight_id) when is_integer(personnel_id) and is_integer(project_id) and is_integer(highlight_id) do
    case HighlightLink.insert(%{user_id: personnel_id, project_id: project_id, highlight_id: highlight_id}) do
      {:ok, _record} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @spec remove_employee_project_highlight(Integer.t(), Integer.t(), Integer.t()) :: :ok | {:error, Atom.t()}
  def remove_employee_project_highlight(personnel_id, project_id, highlight_id) when is_integer(personnel_id) and is_integer(project_id) and is_integer(highlight_id) do
    HighlightLink.delete_many(user_id: personnel_id, project_id: project_id, highlight_id: highlight_id)
  end

  # ----------------------------------------------------------------------------

  @spec link_employee_project(Integer.t(), Integer.t()) :: :ok | {:error, Atom.t()}
  def link_employee_project(personnel_id, project_id) when is_integer(personnel_id) and is_integer(project_id) do
    # case Project.join(:users, personnel_id, id: project_id) do
    #   [:ok] -> :ok
    #   [{:error, :already_exists}] -> {:error, :already_exists}
    #   [{:error, :not_exists}] -> {:error, :not_exists}
    #   [] -> {:error, :not_found}
    # end
    case ProjectLink.insert(%{user_id: personnel_id, project_id: project_id}) do
      {:ok, _record} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  @spec unlink_employee_project(Integer.t(), Integer.t()) :: :ok | {:error, Atom.t()}
  def unlink_employee_project(personnel_id, project_id) when is_integer(personnel_id) and is_integer(project_id) do
    # case Project.leave(:users, personnel_id, id: project_id) do
    #   [:ok] -> :ok
    #   [{:error, :not_exists}] -> {:error, :not_exists}
    #   [] -> {:error, :not_found}
    # end
    ProjectLink.delete_many(user_id: personnel_id, project_id: project_id)
  end

  # ----------------------------------------------------------------------------

  @spec get_teams(Keyword.t()) :: [DbProtocol.Team.t()]
  @doc ~S"""
  Returns list of all teams.

  ## Examples

      iex> [item | _] = Hermes.get_teams()
      iex> is_struct(item, DbProtocol.Team)

      iex> [item] = Hermes.get_teams(title: "CTG Tools")
      iex> is_struct(item, DbProtocol.Team)
      iex> %{id: 1, title: "CTG Tools"} = item

  """
  def get_teams(criteria \\ [order_by: :title]) when is_list(criteria) do
    criteria
      |> Team.all
      |> DbProtocol.Impl.to_team
  end

  @spec get_team!(Integer.t()) :: DbProtocol.Team.t()
  @doc ~S"""
  Returns an existing team by id.

  ## Examples

      iex> item = Hermes.get_team!(1)
      iex> is_struct(item, DbProtocol.Team)
      iex> %{id: 1, title: "CTG Tools"} = item

      iex> Hermes.get_team!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_team!(id) when is_integer(id) do
    [id: id]
      |> Team.one!
      |> DbProtocol.Impl.to_team
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec create_team!(Map.t()) :: DbProtocol.Team.t()
  @doc ~S"""
  Creates a team with specified fields. Returns the team.

  ## Examples

      iex> item = Hermes.create_team!(%{title: "Test Team Foo", created_by: 178})
      iex> is_struct(item, DbProtocol.Team)
      iex> %{id: _, title: "Test Team Foo", created_by_username: "vasya.pupkin"} = item

      iex> Hermes.create_team!(%{})
      ** (DataProtocol.BadRequestError) BadRequestError

  """
  def create_team!(fields) when is_map(fields) do
    case Team.insert(fields) do
      {:ok, record} ->
        get_team!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  end

  @spec update_team!(Integer.t(), Map.t()) :: DbProtocol.Team.t()
  @doc ~S"""
  Updates a team by id with a patch record. Returns the team.

  ## Examples

      iex> item = Hermes.update_team!(1, %{title: "Updated Team"})
      iex> is_struct(item, DbProtocol.Team)
      iex> %{id: 1, title: "Updated Team", rev: 2} = item

      iex> Hermes.update_team!(-1, %{})
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def update_team!(id, patch) when is_integer(id) and is_map(patch) do
    case Team.update(Team.one!(id: id), patch) do
      {:ok, record} ->
        get_team!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec delete_team!(Integer.t()) :: :ok
  @doc ~S"""
  Deletes a team by id.

  ## Examples

      iex> Hermes.delete_team!(1)
      :ok

      iex> Hermes.delete_team!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def delete_team!(id) when is_integer(id) do
    case Team.delete_many(id: id) do
      :ok -> :ok
      {:error, :not_exists} -> raise DataProtocol.NotFoundError
    end
  end

  @spec add_team_member!(Integer.t(), Integer.t()) :: :ok
  @doc ~S"""
  Adds a personnel by id to a team by id.

  ## Examples

      iex> Hermes.add_team_member!(2, 178)
      :ok
      iex> Hermes.add_team_member!(2, 178)
      ** (DataProtocol.BadRequestError) BadRequestError

      iex> Hermes.add_team_member!(-2, 178)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def add_team_member!(team_id, user_id) when is_integer(team_id) and is_integer(user_id) do
    case Team.join(:users, user_id, id: team_id) do
      [:ok] -> :ok
      [{:error, :already_exists}] ->
        raise DataProtocol.BadRequestError, error: :member_already_added
      [{:error, :not_exists}] ->
        raise DataProtocol.BadRequestError, error: :member_not_exists
      [] ->
        raise DataProtocol.NotFoundError
    end
  end

  @spec remove_team_member!(Integer.t(), Integer.t()) :: :ok
  @doc ~S"""
  Removes a personnel by id to a team by id.

  ## Examples

      iex> Hermes.remove_team_member!(2, 178)
      ** (DataProtocol.BadRequestError) BadRequestError
      iex> Hermes.add_team_member!(2, 178)
      :ok
      iex> Hermes.remove_team_member!(2, 178)
      :ok

      iex> Hermes.remove_team_member!(-2, 178)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def remove_team_member!(team_id, user_id) when is_integer(team_id) and is_integer(user_id) do
    case Team.leave(:users, user_id, id: team_id) do
      [:ok] -> :ok
      [{:error, :not_exists}] ->
        raise DataProtocol.BadRequestError, error: :member_not_added
      [] ->
        raise DataProtocol.NotFoundError
    end
  end

  @spec has_team_member?(Integer.t(), Integer.t()) :: boolean
  @doc ~S"""
  Returns whether a personnel by id is a member of a team by id.

  ## Examples

      iex> Hermes.has_team_member?(2, 178)
      false
      iex> Hermes.add_team_member!(2, 178)
      :ok
      iex> Hermes.has_team_member?(2, 178)
      true

      iex> Hermes.has_team_member?(-2, 178)
      false

  """
  def has_team_member?(team_id, user_id) when is_integer(team_id) and is_integer(user_id) do
    case Team.is_member?(:users, user_id, id: team_id) do
      [true] -> true
      _ -> false
    end
  end

  def set_team_manager!(team_id, user_id) when is_integer(team_id) and is_integer(user_id) do
    # case TeamManagerLink.join(:users, user_id, id: team_id) do
    #   [:ok] -> :ok
    #   [{:error, :already_exists}] ->
    #     raise DataProtocol.BadRequestError, error: :manager_already_added
    #   [{:error, :not_exists}] ->
    #     raise DataProtocol.BadRequestError, error: :manager_not_exists
    #   [] ->
    #     raise DataProtocol.NotFoundError
    # end
    case TeamManagerLink.insert(%{user_id: user_id, team_id: team_id}) do
      {:ok, _record} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  def unset_team_manager!(team_id, user_id) when is_integer(team_id) and is_integer(user_id) do
    # case TeamManagerLink.leave(:users, user_id, id: team_id) do
    #   [:ok] -> :ok
    #   [{:error, :not_exists}] ->
    #     raise DataProtocol.BadRequestError, error: :manager_not_added
    #   [] ->
    #     raise DataProtocol.NotFoundError
    # end
    TeamManagerLink.delete_many(user_id: user_id, team_id: team_id)
  end

  def is_team_manager?(team_id, user_id) when is_integer(team_id) and is_integer(user_id) do
    Repo.TeamManagerLink.count(user_id: user_id, team_id: team_id) > 0
  end
  def is_team_manager?(_, _), do: false

  def get_team_managers!(team_id) when is_integer(team_id) do
    [team_id: team_id, preload: :user]
      |> TeamManagerLink.all
      |> Enum.map(& &1.user)
      |> DbProtocol.Impl.to_personnel_account
  end

  # ----------------------------------------------------------------------------

  @spec get_timesheet_cell!(Integer.t()) :: DbProtocol.TimesheetCell.t()
  @doc ~S"""
  Returns an existing timesheet cell by id.

  ## Examples

      iex> item = Hermes.get_timesheet_cell!(19225)
      iex> is_struct(item, DbProtocol.TimesheetCell)
      iex> %{id: 19225, project_name: "Hermes"} = item

      iex> Hermes.get_timesheet_cell!(-1)
      ** (DataProtocol.NotFoundError) NotFoundError

  """
  def get_timesheet_cell!(id) when is_integer(id) do
    [id: id]
      |> TimeCell.one!
      |> DbProtocol.Impl.to_timesheet_cell
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec get_timesheet_cells!([any]) :: [DbProtocol.TimesheetCell.t()]
  def get_timesheet_cells!(criteria) when is_list(criteria) do
    TimeCell.tune(TimeCell, criteria)
      |> TimeCell.all
      |> DbProtocol.Impl.to_timesheet_cell
  end

  @spec update_timesheet!([any], Map.t()) :: [DbProtocol.TimesheetCell.t()]
  def update_timesheet!(criteria, patch) when is_list(criteria) and is_map(patch) do
    TimeCell.for_update()
      |> TimeCell.tune(criteria)
      # |> case do
      #   x ->
      #     IO.inspect({:q, x, Repo.to_sql(:all, x)})
      #     x
      # end
      |> TimeCell.update_many(patch)
      |> case do
        {:ok, cells} ->
          ids = cells
            |> Enum.reduce([], fn [id, _date, _uid, opid, pid, ooff, off, opr, pr], acc ->
              # account only for changed cells
              cond do
                opid === pid and ooff === off and opr === pr -> acc
                true -> [id | acc]
              end
            end)
          [id: ids]
            |> TimeCell.all
            |> DbProtocol.Impl.to_timesheet_cell
        {:error, :not_exists} ->
          []
        # {:error, _} ->
        #   []
      end
  end

  @doc false
  def update_timesheet_cell!(id, patch) when is_integer(id) and is_map(patch) do
    case TimeCell.update(TimeCell.get(id), patch) do
      {:ok, record} ->
        get_timesheet_cell!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  end

  # ----------------------------------------------------------------------------

  defp to_monthly_employee_timesheet(personnel, year, month) when is_list(personnel) and is_integer(year) and is_integer(month) do
    date1 = Date.new!(year, month, 1)
    date2 = date1 |> Date.end_of_month
    personnel = personnel
      |> Enum.filter(& (is_nil(&1.hired_at) or Date.compare(&1.hired_at |> Date.beginning_of_month, date1) != :gt) and (is_nil(&1.fired_at) or Date.compare(date2, &1.fired_at |> Date.end_of_month) != :gt))
    cells = TimeCell.all_for_year_month(year, month, user_id: personnel |> Enum.map(& &1.id))
      |> DbProtocol.Impl.to_timesheet_cell
    personnel
      |> Enum.map(fn personnel ->
        %WebProtocol.MonthlyEmployeeTimesheet{
          personnel_id: personnel.id,
          personnel_username: personnel.username,
          personnel_name: personnel.name,
          allocated_to_project_id: personnel.allocated_to_project_id,
          allocated_to_project_name: personnel.allocated_to_project_name,
          linked_to_projects: personnel.linked_to_projects,
          highlights: personnel.highlights,
          year: year,
          month: month,
          cells: cells |> Enum.filter(& &1.personnel_id == personnel.id)
        }
      end)
  end
  defp to_monthly_employee_timesheet(personnel, year, month) when is_integer(year) and is_integer(month) do
    cells = TimeCell.all_for_year_month(year, month, user_id: personnel.id)
      |> DbProtocol.Impl.to_timesheet_cell
    %WebProtocol.MonthlyEmployeeTimesheet{
      personnel_id: personnel.id,
      personnel_username: personnel.username,
      personnel_name: personnel.name,
      allocated_to_project_id: personnel.allocated_to_project_id,
      allocated_to_project_name: personnel.allocated_to_project_name,
      linked_to_projects: personnel.linked_to_projects,
      highlights: personnel.highlights,
      year: year,
      month: month,
      cells: cells
    }
  end

  @spec get_monthly_timesheet_for_employee(Integer.t(), pos_integer, pos_integer) ::
          WebProtocol.MonthlyEmployeeTimesheet.t()
  def get_monthly_timesheet_for_employee(id, year, month) when is_integer(id) and is_integer(year) and is_integer(month) do
    get_personnel!(id)
      |> to_monthly_employee_timesheet(year, month)
  end

  @spec get_monthly_timesheet_for_project(Integer.t(), pos_integer, pos_integer) ::
          [WebProtocol.MonthlyEmployeeTimesheet.t()]
  def get_monthly_timesheet_for_project(id, year, month) when is_integer(id) and is_integer(year) and is_integer(month) do
    date1 = NaiveDateTime.new!(year, month, 1, 0, 0, 0)
    date2 = date1 |> Date.end_of_month |> Util.Date.to_naive!
    assigned_to_project = get_employees_by_project(id, date1, date2)
      |> to_monthly_employee_timesheet(year, month)
    linked_to_project = (get_employees_linked_to_project(id, date1, date2) -- assigned_to_project)
      |> to_monthly_employee_timesheet(year, month)
    assigned_to_project ++ linked_to_project
  end

  @spec get_monthly_timesheet_for_office(Integer.t(), pos_integer, pos_integer) ::
          [WebProtocol.MonthlyEmployeeTimesheet.t()]
  def get_monthly_timesheet_for_office(id, year, month) when is_integer(id) and is_integer(year) and is_integer(month) do
    get_employees_by_office(id)
      |> to_monthly_employee_timesheet(year, month)
  end

  @spec get_monthly_timesheet_for_team(Integer.t(), pos_integer, pos_integer) ::
          [WebProtocol.MonthlyEmployeeTimesheet.t()]
  def get_monthly_timesheet_for_team(id, year, month) when is_integer(id) and is_integer(year) and is_integer(month) do
    get_employees_by_team(id)
      |> to_monthly_employee_timesheet(year, month)
  end

  @spec get_monthly_timesheet_for_everyone(pos_integer, pos_integer) ::
          [WebProtocol.MonthlyEmployeeTimesheet.t()]
  def get_monthly_timesheet_for_everyone(year, month) when is_integer(year) and is_integer(month) do
    date1 = NaiveDateTime.new!(year, month, 1, 0, 0, 0)
    date2 = date1 |> Date.end_of_month |> Util.Date.to_naive!
    get_active_employees(date1, date2)
      |> to_monthly_employee_timesheet(year, month)
  end

  # ----------------------------------------------------------------------------

  def create_session(user_id) when is_integer(user_id) do
    id = Ecto.UUID.generate()
    ttl = get_settings() |> Map.get(:personnel_session_duration, 600)
    valid_thru = NaiveDateTime.utc_now |> NaiveDateTime.add(ttl, :second)
    Session.insert(%{id: id, user_id: user_id, valid_thru: valid_thru})
  end

  def delete_session(id) when is_binary(id) do
    Session.delete_many(id: id)
  end

  def prolong_session(id) when is_binary(id) do
    ttl = get_settings() |> Map.get(:personnel_session_duration, 600)
    valid_thru = NaiveDateTime.utc_now |> NaiveDateTime.add(ttl, :second)
    Session.update(Session.one!(id: id), valid_thru: valid_thru)
  end

  def delete_sessions_for_user(user_id) when is_integer(user_id) do
    Session.delete_many(user_id: user_id)
    :ok
  end

  def cleanup_expired_sessions() do
    import Ecto.Query, only: [from: 2]
    now = NaiveDateTime.utc_now
    from(x in Session, where: x.valid_thru < ^now)
      |> Repo.delete_all
    :ok
  end

  # ----------------------------------------------------------------------------

  @spec get_visma_reports(Keyword.t()) :: [DbProtocol.VismaReport.t()]
  def get_visma_reports(criteria \\ [order_by: :created_at]) when is_list(criteria) do
    criteria
      |> VismaReport.all
      |> DbProtocol.Impl.to_visma_report
  end

  @spec get_visma_report!(Integer.t()) :: DbProtocol.VismaReport.t()
  def get_visma_report!(id) when is_integer(id) do
    [id: id]
      |> VismaReport.one!
      |> DbProtocol.Impl.to_visma_report
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec create_visma_report!(Map.t()) :: DbProtocol.VismaReport.t()
  def create_visma_report!(%{office_id: office_id, created_by: created_by} = fields) when is_map(fields) do
    %{name: office_name} = get_office!(office_id)
    %{name: created_by_name, username: created_by_username} = get_personnel!(created_by)
    fields = fields
      |> Map.put(:office_name, office_name)
      |> Map.put(:created_by_name, created_by_name)
      |> Map.put(:created_by_username, created_by_username)
    case VismaReport.insert(fields) do
      {:ok, record} ->
        get_visma_report!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  end

  @spec update_visma_report!(Integer.t(), Map.t()) :: DbProtocol.VismaReport.t()
  def update_visma_report!(id, %{updated_by: updated_by} = patch) when is_integer(id) and is_map(patch) do
    %{name: updated_by_name, username: updated_by_username} = get_personnel!(updated_by)
    patch = patch
      |> Map.put(:updated_by_name, updated_by_name)
      |> Map.put(:updated_by_username, updated_by_username)
    case VismaReport.update(VismaReport.one!(id: id), patch) do
      {:ok, record} ->
        get_visma_report!(record.id)
      {:error, error} ->
        raise DataProtocol.BadRequestError, error: error
    end
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  @spec delete_visma_report!(Integer.t()) :: :ok
  def delete_visma_report!(id) when is_integer(id) do
    case VismaReport.delete_many(id: id) do
      :ok -> :ok
      {:error, :not_exists} -> raise DataProtocol.NotFoundError
    end
  end

  @spec get_visma_report_body!(Integer.t()) :: Igor.Json.json()
  def get_visma_report_body!(id) when is_integer(id) do
    [id: id]
      |> VismaReport.one!
      |> Map.get(:report)
  rescue
    Ecto.NoResultsError -> raise DataProtocol.NotFoundError
  end

  # ----------------------------------------------------------------------------

  @spec get_history(Keyword.t()) :: [DbProtocol.HistoryEntry.t()]
  @doc ~S"""
  Returns list of taken actions.

  ## Examples

      # iex> [item | _] = Hermes.get_history()
      # iex> is_struct(item, DbProtocol.HistoryEntry)

  """
  def get_history(criteria \\ []) when is_list(criteria) do
    criteria
      |> History.all
      |> DbProtocol.Impl.to_history_entry
  end

  @spec count_history(Keyword.t()) :: Integer.t()
  @doc ~S"""
  Returns amount of taken actions.

  ## Examples

      iex> n = Hermes.count_history()
      iex> is_integer(n) and n >= 0

  """
  def count_history(criteria \\ []) when is_list(criteria) do
    criteria
      |> History.count
  end

  @spec get_timesheet_history_for_day_employee(pos_integer, pos_integer, pos_integer, Integer.t()) :: [DbProtocol.HistoryEntry.t()]
  def get_timesheet_history_for_day_employee(year, month, day, employee_id) when is_integer(employee_id) and is_integer(year) and is_integer(month) and is_integer(day) do
    ids = History.get_ids_for_year_month_day_employee(:timecell, year, month, day, employee_id)
    get_history(id: ids)
  end

  @spec get_monthly_timesheet_history_for_employee(pos_integer, pos_integer, Integer.t()) :: [DbProtocol.HistoryEntry.t()]
  def get_monthly_timesheet_history_for_employee(year, month, employee_id) when is_integer(employee_id) and is_integer(year) and is_integer(month) do
    ids = History.get_ids_for_year_month_employees(:timecell, year, month, [employee_id])
    get_history(id: ids)
  end

  @spec get_monthly_timesheet_history_for_project(pos_integer, pos_integer, Integer.t()) :: [DbProtocol.HistoryEntry.t()]
  def get_monthly_timesheet_history_for_project(year, month, project_id) when is_integer(project_id) and is_integer(year) and is_integer(month) do
    date1 = NaiveDateTime.new!(year, month, 1, 0, 0, 0)
    date2 = date1 |> Date.end_of_month |> Util.Date.to_naive!
    relevant_employee_ids = get_employees_by_project(project_id, date1, date2)
      |> Enum.map(& &1.id)
    ids = History.get_ids_for_year_month_employees(:timecell, year, month, relevant_employee_ids)
    get_history(id: ids)
  end

  @spec get_monthly_timesheet_history_for_office(pos_integer, pos_integer, Integer.t()) :: [DbProtocol.HistoryEntry.t()]
  def get_monthly_timesheet_history_for_office(year, month, office_id) when is_integer(office_id) and is_integer(year) and is_integer(month) do
    ids = History.get_ids_for_year_month_office(:timecell, year, month, office_id)
    get_history(id: ids)
  end

  @spec get_monthly_timesheet_history_for_team(pos_integer, pos_integer, Integer.t()) :: [DbProtocol.HistoryEntry.t()]
  def get_monthly_timesheet_history_for_team(year, month, team_id) when is_integer(team_id) and is_integer(year) and is_integer(month) do
    ids = History.get_ids_for_year_month_team(:timecell, year, month, team_id)
    get_history(id: ids)
  end

  @spec get_role_history_for_employee!(Integer.t()) :: [DbProtocol.HistoryEntry.t()]
  def get_role_history_for_employee!(personnel_id) when is_integer(personnel_id) do
    History.all_for_employee(personnel_id)
      |> History.all
      |> DbProtocol.Impl.to_history_entry
  end

  @spec get_role_history_for_office!(Integer.t()) :: [DbProtocol.HistoryEntry.t()]
  def get_role_history_for_office!(office_id) when is_integer(office_id) do
    History.all_for_office(office_id)
      |> History.all
      |> DbProtocol.Impl.to_history_entry
  end

  # ----------------------------------------------------------------------------

  @doc ~S"""
  Returns an user rights.

  ## Examples

      iex> rights = Hermes.get_personnel_rights(178)
      iex> %WebProtocol.PersonnelRights{} = rights

      iex> Hermes.get_personnel_rights(-1)
      %WebProtocol.PersonnelRights{}

  """
  def get_personnel_rights(user_id, entities \\ []) when is_integer(user_id) and is_list(entities) do
    # import Ecto.Query, only: [from: 2]
    # query = from u in User,
    #   where: u.id == ^user_id,
    #   left_join: o in Office, on: u.office_id == o.id,
    #   left_join: g in assoc(u, :groups),
    #   # fragment("user_group_membership", ^name)
    #   left_join: p in Project, on: u.id == p.supervisor_id,
    #   select_merge: %{
    #     can_login?: not is_nil(u.office_id),
    #     groups: g,
    #   }
    # query |> Repo.all

    user = User.one!(id: user_id, preload: [:office, :groups, :teams])
    personnel_id = Keyword.get(entities, :personnel)
    office_id = Keyword.get(entities, :office)
    project_id = Keyword.get(entities, :project)
    team_id = Keyword.get(entities, :team)
    employee = not is_nil(personnel_id) and get_employee!(personnel_id)
    _office = not is_nil(office_id) and get_office!(office_id)
    project = not is_nil(project_id) and get_project!(project_id)
    team = not is_nil(team_id) and get_team!(team_id)
    is_superadmin = user.groups |> Enum.any?(& &1.is_superadmin)
    is_inactive = user.is_deleted or user.is_blocked
    has_office = not is_nil(user.office_id)
    employee_office = employee && employee.office_id
    project_office = project && project.leading_office_id
    can_login = is_superadmin or has_office
    is_the_office_manager = has_office and user.is_office_manager and user.office_id == employee_office
    is_the_office_or_project_manager = has_office and user.is_office_manager and (user.office_id == employee_office or user.office_id == project_office)
    is_project_supervisor = (project && project.supervisor_id) == user_id
    is_project_led_by_office = has_office and user.is_office_manager and (project_office == user.office_id)
    is_team_creator = user.is_office_manager and (team && team.created_by) == user_id
    is_team_manager = is_team_manager?(team_id, user_id)
    # IO.inspect({:gur, is_project_led_by_office})
    rights = %WebProtocol.PersonnelRights{
      can_login:
        can_login,

      can_update_personnel:
        is_superadmin or is_the_office_manager,
      can_allocate_employee:
        is_superadmin
          or is_project_supervisor or is_project_led_by_office
          or is_the_office_or_project_manager
          or is_team_manager,
      can_deallocate_employee:
        is_superadmin
          or is_project_supervisor or is_project_led_by_office
          or is_the_office_or_project_manager
          or is_team_manager,
      can_link_project:
        is_superadmin # or is_the_office_manager,
          or is_project_supervisor or is_project_led_by_office
          or is_the_office_or_project_manager,

      can_create_office:
        is_superadmin,
      can_update_office:
        is_superadmin,
      can_delete_office:
        is_superadmin,

      can_get_projects:
        can_login,
      can_get_project:
        can_login,
      can_create_project:
        is_superadmin,
      can_update_project:
        is_superadmin
          or is_the_office_or_project_manager,
      can_delete_project:
        is_superadmin,

      can_get_visma_report:
        can_login,
      can_create_visma_report:
        can_login,
      can_update_visma_report:
        can_login,

      can_get_roles:
        can_login,
      can_get_role:
        can_login,
      can_create_role:
        is_superadmin,
      can_update_role:
        is_superadmin,
      can_delete_role:
        is_superadmin,

      can_get_teams:
        can_login,
      can_get_team:
        can_login,
      can_create_team:
        is_superadmin
          or user.is_office_manager,
      can_update_team:
        is_superadmin
          or is_team_creator,
      can_delete_team:
        is_superadmin
          or is_team_creator,
      can_add_team_members:
        is_superadmin
          or is_team_creator
          or is_team_manager,
      can_remove_team_members:
        is_superadmin
          or is_team_creator
          or (is_team_manager and personnel_id != user_id and personnel_id != team.created_by),
      can_set_team_manager:
        is_superadmin
          or is_team_creator,

      can_get_highlights:
        can_login,
      can_get_highlight:
        can_login,
      can_create_highlight:
        is_superadmin
          or user.is_office_manager,
      can_update_highlight:
        is_superadmin
          or user.is_office_manager,
      can_delete_highlight:
        is_superadmin
          or user.is_office_manager,
      can_assign_highlights:
        is_superadmin
          or user.is_office_manager,

      can_modify_role_for_office:
        is_superadmin
          or user.is_office_manager and user.office_id == office_id,

      can_get_timesheet:
        can_login,
      can_protect_timesheet:
        is_superadmin
          or user.is_office_manager,
      can_unprotect_timesheet:
        is_superadmin,

      can_regenerate_timesheet:
        is_superadmin,

      can_sync_bamboo:
        is_superadmin
          or is_project_supervisor
          or is_the_office_or_project_manager,

      can_sync_ldap:
        is_superadmin,
    }
    # NB: inactive user has no rights
    case is_inactive do
      true -> %WebProtocol.PersonnelRights{}
      false -> rights
    end
  rescue
    Ecto.NoResultsError -> %WebProtocol.PersonnelRights{}
  end

  @doc ~S"""
  Returns whether an user can login.

  ## Examples

      iex> Hermes.can_login?(178)
      true

      iex> Hermes.can_login?(-1)
      false

      iex> Hermes.can_login?(nil)
      false

  """
  def can_login?(nil), do: false
  def can_login?(user_id) when is_integer(user_id) do
    get_personnel_rights(user_id).can_login
  end
  def can_login?(%{user_id: user_id}) when is_integer(user_id) do
    can_login?(user_id)
  end

  @doc ~S"""
  Returns whether an user can update a personnel.

  ## Examples

      iex> Hermes.can_update_personnel?(%{user_id: 178}, 178)
      true

      iex> Hermes.can_update_personnel?(%{user_id: 113}, 178)
      false

      iex> Hermes.can_update_personnel?(%{user_id: -1}, 178)
      false

      iex> Hermes.can_update_personnel?(nil, 178)
      false

  """
  def can_update_personnel?(nil, _), do: false
  def can_update_personnel?(%{user_id: user_id}, personnel_id) when is_integer(personnel_id) do
    get_personnel_rights(user_id, personnel: personnel_id).can_update_personnel
  end

  def can_allocate_employee?(nil, _, _), do: false
  def can_allocate_employee?(%{user_id: user_id}, personnel_id, project_id) when is_integer(personnel_id) and is_integer(project_id) do
    get_personnel_rights(user_id, personnel: personnel_id, project: project_id).can_allocate_employee
  end

  def can_deallocate_employee?(nil, _), do: false
  def can_deallocate_employee?(%{user_id: user_id}, personnel_id) when is_integer(personnel_id) do
    get_personnel_rights(user_id, personnel: personnel_id).can_deallocate_employee
  end

  def can_link_project?(nil, _, _), do: false
  def can_link_project?(%{user_id: user_id}, personnel_id, project_id) when is_integer(personnel_id) and is_integer(project_id) do
    get_personnel_rights(user_id, personnel: personnel_id, project: project_id).can_link_project
  end

  def can_create_office?(nil), do: false
  def can_create_office?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_create_office
  end

  def can_update_office?(nil, _), do: false
  def can_update_office?(%{user_id: user_id}, office_id) when is_integer(office_id) do
    get_personnel_rights(user_id, office: office_id).can_update_office
  end

  def can_delete_office?(nil, _), do: false
  def can_delete_office?(%{user_id: user_id}, office_id) when is_integer(office_id) do
    get_personnel_rights(user_id, office: office_id).can_delete_office
  end

  def can_get_projects?(nil), do: false
  def can_get_projects?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_get_projects
  end

  def can_get_project?(nil, _), do: false
  def can_get_project?(%{user_id: user_id}, project_id) when is_integer(project_id) do
    get_personnel_rights(user_id, project: project_id).can_get_project
  end

  def can_create_project?(nil), do: false
  def can_create_project?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_create_project
  end

  def can_update_project?(nil, _), do: false
  def can_update_project?(%{user_id: user_id}, project_id) when is_integer(project_id) do
    get_personnel_rights(user_id, project: project_id).can_update_project
  end

  def can_delete_project?(nil, _), do: false
  def can_delete_project?(%{user_id: user_id}, project_id) when is_integer(project_id) do
    get_personnel_rights(user_id, project: project_id).can_delete_project
  end

  def can_get_visma_report?(nil), do: false
  def can_get_visma_report?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_get_visma_report
  end

  def can_create_visma_report?(nil), do: false
  def can_create_visma_report?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_create_visma_report
  end

  def can_update_visma_report?(nil), do: false
  def can_update_visma_report?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_update_visma_report
  end

  def can_get_roles?(nil), do: false
  def can_get_roles?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_get_roles
  end

  def can_get_role?(nil, _), do: false
  def can_get_role?(%{user_id: user_id}, role_id) when is_integer(role_id) do
    get_personnel_rights(user_id, role: role_id).can_get_role
  end

  def can_create_role?(nil), do: false
  def can_create_role?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_create_role
  end

  def can_update_role?(nil, _), do: false
  def can_update_role?(%{user_id: user_id}, role_id) when is_integer(role_id) do
    get_personnel_rights(user_id, role: role_id).can_update_role
  end

  def can_delete_role?(nil, _), do: false
  def can_delete_role?(%{user_id: user_id}, role_id) when is_integer(role_id) do
    get_personnel_rights(user_id, role: role_id).can_delete_role
  end

  def can_get_teams?(nil), do: false
  def can_get_teams?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_get_teams
  end

  def can_get_team?(nil, _), do: false
  def can_get_team?(%{user_id: user_id}, team_id) when is_integer(team_id) do
    get_personnel_rights(user_id, team: team_id).can_get_team
  end

  def can_create_team?(nil), do: false
  def can_create_team?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_create_team
  end

  def can_update_team?(nil, _), do: false
  def can_update_team?(%{user_id: user_id}, team_id) when is_integer(team_id) do
    get_personnel_rights(user_id, team: team_id).can_update_team
  end

  def can_delete_team?(nil, _), do: false
  def can_delete_team?(%{user_id: user_id}, team_id) when is_integer(team_id) do
    get_personnel_rights(user_id, team: team_id).can_delete_team
  end

  def can_add_team_members?(nil, _), do: false
  def can_add_team_members?(%{user_id: user_id}, team_id) when is_integer(team_id) do
    get_personnel_rights(user_id, team: team_id).can_add_team_members
  end

  def can_remove_team_members?(nil, _), do: false
  def can_remove_team_members?(%{user_id: user_id}, team_id) when is_integer(team_id) do
    get_personnel_rights(user_id, team: team_id).can_remove_team_members
  end

  def can_set_team_manager?(nil, _), do: false
  def can_set_team_manager?(%{user_id: user_id}, team_id) when is_integer(team_id) do
    get_personnel_rights(user_id, team: team_id).can_set_team_manager
  end

  def can_get_highlights?(nil), do: false
  def can_get_highlights?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_get_highlights
  end

  def can_get_highlight?(nil), do: false
  def can_get_highlight?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_get_highlight
  end

  def can_create_highlight?(nil), do: false
  def can_create_highlight?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_create_highlight
  end

  def can_update_highlight?(nil), do: false
  def can_update_highlight?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_update_highlight
  end

  def can_delete_highlight?(nil), do: false
  def can_delete_highlight?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_delete_highlight
  end

  def can_assign_highlights?(nil), do: false
  def can_assign_highlights?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_assign_highlights
  end

  def can_modify_role_for_office?(session, entities \\ [])
  def can_modify_role_for_office?(nil, _), do: false
  def can_modify_role_for_office?(%{user_id: user_id}, office_id) do
    get_personnel_rights(user_id, office: office_id).can_modify_role_for_office
  end

  def can_get_timesheet?(session, entities \\ [])
  def can_get_timesheet?(nil, _), do: false
  def can_get_timesheet?(%{user_id: user_id}, entities) do
    get_personnel_rights(user_id, entities).can_get_timesheet
  end

  def can_protect_timesheet?(session, entities \\ [])
  def can_protect_timesheet?(nil, _), do: false
  def can_protect_timesheet?(%{user_id: user_id}, entities) do
    get_personnel_rights(user_id, entities).can_protect_timesheet
  end

  def can_unprotect_timesheet?(session, entities \\ [])
  def can_unprotect_timesheet?(nil, _), do: false
  def can_unprotect_timesheet?(%{user_id: user_id}, entities) do
    get_personnel_rights(user_id, entities).can_unprotect_timesheet
  end

  def can_regenerate_timesheet?(session, entities \\ [])
  def can_regenerate_timesheet?(nil, _), do: false
  def can_regenerate_timesheet?(%{user_id: user_id}, entities) do
    get_personnel_rights(user_id, entities).can_regenerate_timesheet
  end

  def can_sync_bamboo?(session, entities \\ [])
  def can_sync_bamboo?(nil, _), do: false
  def can_sync_bamboo?(%{user_id: user_id}, entities) do
    get_personnel_rights(user_id, entities).can_sync_bamboo
  end

  def can_sync_ldap?(nil), do: false
  def can_sync_ldap?(%{user_id: user_id}) do
    get_personnel_rights(user_id).can_sync_ldap
  end

  # ----------------------------------------------------------------------------
  # TODO: refactor below functions
  # ----------------------------------------------------------------------------

  def sync_ldap(_opts \\ []) do
    require Logger

    # fetch groups from LDAP
    new_groups = Auth.Ldap.groups()
    group_map = new_groups
      |> Map.new(fn %{name: name} -> {name |> String.downcase, name} end)
    new_groups_set = new_groups
      |> Enum.map(& &1.name |> String.downcase)
      |> MapSet.new
    # get existing groups
    existing_groups = Group.all([])
    existing_groups_set = existing_groups
      |> Enum.map(& &1.name |> String.downcase)
      |> MapSet.new
    # determine groups to create / update / deactivate
    groups_to_create = MapSet.difference(new_groups_set, existing_groups_set)
    groups_to_update = MapSet.intersection(new_groups_set, existing_groups_set)
    groups_to_deactivate = MapSet.difference(existing_groups_set, new_groups_set)
    # create new groups
    for name <- groups_to_create do
      Logger.info("Creating new Group: #{group_map[name]}")
      {:ok, _group} = Group.insert(%{name: group_map[name]})
    end
    # update existing groups
    for group <- Enum.filter(existing_groups, & &1.name in groups_to_update and &1.is_deleted) do
      Logger.info("Updating Group: #{group.name}")
      Group.update(group, is_deleted: false)
    end
    # deactivate deleted groups
    for group <- Enum.filter(existing_groups, & &1.name in groups_to_deactivate and not &1.is_deleted) do
      Logger.info("Deactivating Group: #{group.name}")
      Group.update(group, is_deleted: true)
    end
    # set superadmin group
    superadmin_group = Util.config!(:hermes, [:access, :admin_group])
    Logger.info("Setting superadmin Group: #{superadmin_group}")
    Group.set_superadmin(superadmin_group)

    # fetch users from LDAP
    new_users = Auth.Ldap.users()
    user_map = new_users
      |> Map.new(fn %{dn: dn} = attrs -> {dn, Util.take(attrs, [
          username: [:uid],
          email: [:mail],
          name: [:cn]
        ])} end)
    new_users_set = new_users
      |> Enum.map(& &1.uid |> String.downcase)
      |> MapSet.new
    # get existing users
    existing_users = User.all([])
    existing_users_set = existing_users
      |> Enum.map(& &1.username |> String.downcase)
      |> MapSet.new
    # determine users to create / update / deactivate
    users_to_create = MapSet.difference(new_users_set, existing_users_set)
    users_to_update = MapSet.intersection(new_users_set, existing_users_set)
    users_to_deactivate = MapSet.difference(existing_users_set, new_users_set)
    # create new users
    for {_, user} <- Enum.filter(user_map, fn {_, user} -> user.username in users_to_create end) do
      Logger.info("Creating new User: #{user.username}")
      case User.insert(user) do
        {:ok, _user} -> :ok
        {:error, reason} ->
          Logger.error("Creating new User: #{user.username} failed with #{inspect(reason)}")
          :ok
      end
    end
    # update existing users
    for user <- Enum.filter(existing_users, & &1.username in users_to_update and &1.is_deleted) do
      Logger.info("Updating User: #{user.username}")
      User.update(user, is_deleted: false)
    end
    # deactivate deleted users
    for user <- Enum.filter(existing_users, & &1.username in users_to_deactivate and not &1.is_deleted) do
      Logger.info("Deactivating User: #{user.username}")
      User.update(user, is_deleted: true, email: "deleted-#{user.email}")
    end
    # update name and email
    for {_, ldap_user} <- user_map do
      case User.all(username: ldap_user.username) do
        [] -> :skip
        [user] ->
          {:ok, _user} = User.update(user, name: ldap_user.name, email: ldap_user.email)
      end
    end

    # TODO: FIXME: reconsider this crap!
    # TODO: implement membership revoking
    for %{name: name, members: members} <- new_groups do
      group = Group.one!(name: name)
      # group = existing_groups
      #   |> Enum.filter(& &1.name === name)
      #   |> List.first
      #   |> Map.take([:id])
      for member <- members do
        case user_map[member][:email] do
          nil -> :skip
          email ->
            case User.all(email: email, preload: [:groups]) do
              [] -> :skip
              [user] ->
                # set group
                if not Enum.any?(user.groups, & &1.id == group.id) do
                  User.join(:groups, group.id, id: user.id)
                end
                # set group office
                group
                  # TODO: FIXME: unify via to_personnel_account?
                  |> Repo.preload([:offices])
                  |> Map.get(:offices)
                  |> List.first
                  |> case do
                    nil -> :skip
                    office when user.office_id === nil ->
                      User.update(user, office_id: office.id)
                    _ -> :skip
                  end
            end
        end
      end
    end
    # :ok

    # create cells for new users
    if MapSet.size(users_to_create) > 0 do
      ensure_cells()
    end

    Hermes.sync_bamboo()
  end

  # ----------------------------------------------------------------------------

  def sync_bamboo(_opts \\ []) do
    require Logger

    #bamboos = Util.config!(:hermes, [:bamboo])
    #for {_, bamboo} <- bamboos do
    #  users = Auth.Bamboo.request_custom_report(bamboo)
    #  ...
    #end

    :ok
  end

  def sync_timeoffs() do
    today = Date.utc_today
    sync_timeoffs(today.year, today.month)
  end
  def sync_timeoffs(year, month) when is_integer(year) and is_integer(month) do
    require Logger

    Logger.info("sync_timeoffs for #{year}-#{month} started")

    date1 = Date.new!(year, month, 1)
    date2 = date1 |> Date.end_of_month

    # collect timeoffs
    Logger.info("Collecting timeoffs for #{date1} -:- #{date2}")
    timeoffs = get_timeoffs(date1, date2)

    # update timesheet cells
    apply_timeoffs(year, month, timeoffs)

    Logger.info("sync_timeoffs for #{year}-#{month} finished")
    :ok
  end

  def get_timeoffs() do
    today = Date.utc_today
    get_timeoffs(today.year, today.month)
  end
  def get_timeoffs(year, month) when is_integer(year) and is_integer(month) do
    date1 = Date.new!(year, month, 1)
    date2 = date1 |> Date.end_of_month
    get_timeoffs(date1, date2)
  end
  def get_timeoffs(date1, date2) do
    # bamboo_timeoffs = Util.config!(:hermes, [:bamboo])
    #   |> Enum.reduce([], fn {_, config}, acc ->
    #     acc ++ fetch_bamboo_timeoffs(config, date1, date2)
    #   end)
    # hrvey_timeoffs = fetch_hrvey_timeoffs(Util.config!(:hermes, [:hrvey]), date1, date2)
    # bamboo_timeoffs ++ hrvey_timeoffs
    fetch_hrvey_timeoffs(Util.config!(:hermes, [:hrvey]), date1, date2)
  end

  def apply_timeoffs(year, month, timeoffs) when is_integer(year) and is_integer(month) and is_list(timeoffs) do
    require Logger

    date1 = Date.new!(year, month, 1)
    date2 = date1 |> Date.end_of_month

    {:ok, _} = Repo.transaction(fn ->

      # clean revoked timeoffs
      Logger.info("Revoking timeoffs for #{date1} -:- #{date2}")
      Repo.query!(
        "UPDATE timecells t SET time_off = NULL, project_id = saved_project_id, saved_project_id = NULL, set_by = NULL WHERE set_by = -1 AND (t.slot_date BETWEEN $1 AND $2) AND NOT t.is_protected",
        [date1 |> Util.Date.to_naive!, date2 |> Util.Date.to_naive!]
      )

      # set approved timeoffs
      Logger.info("Setting timeoffs for #{date1} -:- #{date2}")
      for {uid, timeoff, start, finish} <- timeoffs do
        Repo.query!(
          "UPDATE timecells t SET time_off = $1, saved_project_id = project_id, project_id = NULL, set_by = -1 WHERE t.user_id = $2 AND (t.slot_date BETWEEN $3 AND $4) AND (extract(dow FROM t.slot_date) BETWEEN 1 AND 5) AND NOT t.is_protected",
          [timeoff && timeoff |> to_string, uid, start |> Util.Date.to_naive!, finish |> Util.Date.to_naive!]
        )
      end

    end)
    :ok
  end

  defp fetch_bamboo_timeoffs(config, date1, date2) do
    %{employees: employees} = Auth.Bamboo.request_custom_report(config)
    map_id_to_user = employees
      |> Enum.map(& {Map.get(&1, :id), List.first(User.all(%{email: Map.get(&1, :work_email), name: Map.get(&1, :display_name)}))})
      |> Enum.into(%{})
    timeoff_types = config[:timeoffs]
    Auth.Bamboo.get_time_off_requests(config, Util.Date.to_json!(date1), Util.Date.to_json!(date2))
      |> Enum.filter(fn %{status: %BambooProtocol.TimeOffRequestStatus{status: status}} -> status == "approved" end)
      |> Enum.reduce([], fn %{employee_id: eid, start: start, end: finish, type: %{id: tid}}, acc ->
        case Map.get(map_id_to_user, to_string(eid)) do
          nil ->
            # IO.inspect(["nomatch", eid, config])
            acc
          user ->
            case timeoff_types[tid] do
              nil -> acc
              timeoff -> [{user.id, timeoff, start, finish} | acc]
            end
        end
      end)
  end

  defp fetch_hrvey_timeoffs(config, date1, date2) do
    users = User.all(is_deleted: false)
    employees = users
      |> Enum.map(& [{&1.username, &1.id}, {&1.email, &1.id}, {&1.name, &1.id}])
      |> List.flatten()
      |> Enum.into(%{})
    timeoff_types = config[:timeoffs]
    timeoffs = HrveyProtocol.HrveyApi.get_time_off_report(config[:url], false, Util.Date.to_json!(date1), Util.Date.to_json!(date2), "Bearer #{Jason.encode!(%{email: config[:email], password: config[:password]})}")
    missing_timeoff_types = timeoffs
      |> Enum.map(& &1.time_off)
      |> List.flatten()
      |> Enum.map(& &1.type)
      |> Enum.uniq()
      |> Enum.filter(& Map.get(timeoff_types, &1) === nil)
    if length(missing_timeoff_types) != 0 do
      require Logger
      Logger.warning("The following timeoffs won't be applied: #{inspect missing_timeoff_types}! Consider mapping them to known timeoff types: #{inspect timeoff_types}")
    end
    timeoffs
      |> Enum.map(fn x -> x.time_off |> Enum.map(& {employees[x.employee_id] || employees[x.email] || Map.get(employees, x.name, nil), Map.get(timeoff_types, &1.type, nil), &1.date, &1.date}) end)
      |> List.flatten()
  end

  @spec ensure_cells :: :ok
  def ensure_cells() do
    require Logger

    Logger.info("ensure_cells started")

    today = Date.utc_today
    date1 = today |> Date.beginning_of_month
    date2 = Date.new!(today.year + 3, 12, 31)

    Repo.query!(
      "CALL ensure_cells($1, $2)",
      [date1, date2]
    )

    Logger.info("ensure_cells finished")
    :ok
  end

  @spec ensure_cells(Integer.t(), Integer.t()) :: :ok
  def ensure_cells(year, month) when is_integer(year) and is_integer(month) do
    require Logger

    Logger.info("ensure_cells started")

    date1 = Date.new!(year, month, 1)
    date2 = date1 |> Date.end_of_month

    Repo.query!(
      "CALL ensure_cells($1, $2)",
      [date1, date2]
    )

    Logger.info("ensure_cells finished")
    :ok
  end

  @spec prolong_user_assignment :: :ok
  def prolong_user_assignment() do
    require Logger

    # skip for weekends
    today = Date.utc_today
    if Date.day_of_week(today) <= 5 do
      Logger.info("prolong_user_assignment started")
      # set next work day project to unprotected unallocated cells
      now = NaiveDateTime.utc_now
      %Postgrex.Result{num_rows: updated} = Repo.query!("
        WITH cells AS (
            SELECT c.id cid, u.assigned_to pid
            FROM timecells c INNER JOIN users u ON u.id = c.user_id
            WHERE u.assigned_to IS NOT NULL AND NOT u.is_deleted
              AND c.slot_date = $1 AND (c.time_off IS NULL AND c.project_id IS NULL) AND NOT c.is_protected
        )
        UPDATE timecells
            SET project_id = cells.pid, updated_at = $2
        FROM cells
        WHERE id = cells.cid",
        [today |> Util.Date.to_naive!, now]
      )
      Logger.info("prolong_user_assignment finished; updated #{updated} cells")
    end
    :ok
  end

  # ----------------------------------------------------------------------------

  def log_user_action(session, object) when is_map(object) do
    actor = case session do
      %{user_id: actor_id, name: actor_name, username: actor_username} ->
        %{
          actor: :user,
          actor_id: actor_id,
          actor_name: actor_name,
          actor_username: actor_username
        }
      nil ->
        %{
          user_id: 0,
          name: "System",
          username: "system"
        }
    end
    record = Map.merge(object, actor)
    # IO.inspect({:lua, record})
    History.insert!(record)
  end

  # ----------------------------------------------------------------------------

end
