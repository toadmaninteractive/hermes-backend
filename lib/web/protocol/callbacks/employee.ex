defmodule WebProtocol.HermesEmployeeService.Impl do

  require WebProtocol.PersonnelAccountOrderBy
  require DataProtocol.OrderDirection
  require Util.Date

  @behaviour WebProtocol.HermesEmployeeService

  # ----------------------------------------------------------------------------

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

  def router() do
    quote do
      match "/api/employees", to: WebProtocol.HermesEmployeeService.GetEmployees
      match "/api/employees/office/:office_id", to: WebProtocol.HermesEmployeeService.GetEmployeesByOffice
      match "/api/employees/project/:project_id", to: WebProtocol.HermesEmployeeService.GetEmployeesByProject
      match "/api/employees/username/:username", to: WebProtocol.HermesEmployeeService.GetEmployeeByUsername
      match "/api/employees/:id", to: WebProtocol.HermesEmployeeService.GetEmployee
      match "/api/employees/:id/alloc", to: WebProtocol.HermesEmployeeService.EmployeeAlloc
      match "/api/employees/:personnel_id/project/:project_id", to: WebProtocol.HermesEmployeeService.EmployeeProject
      match "/api/employees/:personnel_id/project/:project_id/highlight/:highlight_id", to: WebProtocol.HermesEmployeeService.EmployeeHighlight
    end
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get employee by ID
  """
  @spec get_employee(
    id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def get_employee(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_employee!(id)
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get employee by username
  """
  @spec get_employee_by_username(
    username :: String.t(),
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def get_employee_by_username(
    username,
    session
  ) when
    is_binary(username)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_employee_by_username!(username)
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get employees
  """
  @spec get_employees(
    needle :: String.t() | nil,
    order_by :: WebProtocol.PersonnelAccountOrderBy.t(),
    order_dir :: DataProtocol.OrderDirection.t(),
    offset :: integer,
    limit :: integer,
    session :: any()
  ) :: DataProtocol.CollectionSlice.t(DbProtocol.PersonnelAccount.t())
  @impl true
  def get_employees(
    needle,
    order_by,
    order_dir,
    offset,
    limit,
    session
  ) when
    (is_binary(needle) or needle === nil) and
    WebProtocol.PersonnelAccountOrderBy.is_personnel_account_order_by(order_by) and
    DataProtocol.OrderDirection.is_order_direction(order_dir) and
    is_integer(offset) and
    is_integer(limit)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    needle = needle && "%#{needle}%"
    total = Hermes.count_personnels(name: needle, username: needle)
    items = Hermes.get_personnels(name: needle, username: needle, order_by: [{order_dir, order_by}], offset: offset, limit: limit)
    struct!(DataProtocol.CollectionSlice, %{total: total, items: items})
  end

  #-----------------------------------------------------------------------------

  @doc """
  Get all employee for supplied office
  """
  @spec get_employees_by_office(
    office_id :: integer,
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.PersonnelAccount.t())
  @impl true
  def get_employees_by_office(
    office_id,
    session
  ) when
    is_integer(office_id)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_office!(office_id)
    items = Hermes.get_employees_by_office(office_id)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Get all employee assigned to supplied project
  """
  @spec get_employees_by_project(
    project_id :: integer,
    since :: CommonProtocol.date() | nil,
    till :: CommonProtocol.date() | nil,
    session :: any()
  ) :: DataProtocol.Collection.t(DbProtocol.PersonnelAccount.t())
  @impl true
  def get_employees_by_project(
    project_id,
    since,
    till,
    session
  ) when
    is_integer(project_id) and
    (Util.Date.is_date(since) or since === nil) and
    (Util.Date.is_date(till) or till === nil)
  do
    unless Hermes.can_login?(session), do: raise DataProtocol.ForbiddenError
    Hermes.get_project!(project_id)
    today = Date.utc_today
    date1 = (since || (today |> Date.beginning_of_month)) |> Util.Date.to_naive!
    date2 = (till || (today |> Date.end_of_month)) |> Util.Date.to_naive!
    items = Hermes.get_employees_by_project(project_id, date1, date2)
    struct!(DataProtocol.Collection, %{items: items})
  end

  # ----------------------------------------------------------------------------

  @doc """
  Allocate employee to project
  """
  @spec allocate_employee(
    request_content :: WebProtocol.EmployeeAlloc.t(),
    id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def allocate_employee(
    %{project_id: project_id} = request_content,
    id,
    session
  ) when
    is_struct(request_content, WebProtocol.EmployeeAlloc) and
    is_integer(id)
  do
    unless Hermes.can_allocate_employee?(session, id, project_id), do: raise DataProtocol.ForbiddenError
    # project = Hermes.get_project!(project_id)
    employee = Hermes.allocate_employee!(id, project_id)
    log_user_action(session, :allocate, employee)
    employee
  end

  # ----------------------------------------------------------------------------

  @doc """
  Deallocate employee from project
  """
  @spec deallocate_employee(
    id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def deallocate_employee(
    id,
    session
  ) when
    is_integer(id)
  do
    unless Hermes.can_deallocate_employee?(session, id), do: raise DataProtocol.ForbiddenError
    employee = Hermes.allocate_employee!(id, nil)
    log_user_action(session, :deallocate, employee)
    employee
  end

  # ----------------------------------------------------------------------------

  @doc """
  Add an employee highlight to particular project
  """
  @spec add_employee_highlight(
    request_content :: CommonProtocol.Empty.t(),
    personnel_id :: integer,
    project_id :: integer,
    highlight_id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def add_employee_highlight(
    request_content,
    personnel_id,
    project_id,
    highlight_id,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty) and
    is_integer(personnel_id) and
    is_integer(project_id) and
    is_integer(highlight_id)
  do
    unless Hermes.can_assign_highlights?(session), do: raise DataProtocol.ForbiddenError
    personnel = Hermes.get_employee!(personnel_id)
    project = Hermes.get_project!(project_id)
    highlight = Hermes.get_highlight!(highlight_id)
    rc = Hermes.add_employee_project_highlight(personnel_id, project_id, highlight_id)
    employee = Hermes.get_employee!(personnel_id)
    if rc == :ok do
      Hermes.log_user_action(session, %{
        operation: :create,
        entity: :project_highlight_membership,
        properties: %{
          affects: [Util.take(personnel, [:id, :name, :username])],
          data: %{
            project: Util.take(project, [:id, :title]),
            highlight: Util.take(highlight, [:id, :code, :title])
          }
        }
      })
    end
    employee
  end

  # ----------------------------------------------------------------------------

  @doc """
  Add an employee highlight from particular project
  """
  @spec remove_employee_highlight(
    personnel_id :: integer,
    project_id :: integer,
    highlight_id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def remove_employee_highlight(
    personnel_id,
    project_id,
    highlight_id,
    session
  ) when
    is_integer(personnel_id) and
    is_integer(project_id) and
    is_integer(highlight_id)
  do
    unless Hermes.can_assign_highlights?(session), do: raise DataProtocol.ForbiddenError
    personnel = Hermes.get_employee!(personnel_id)
    project = Hermes.get_project!(project_id)
    highlight = Hermes.get_highlight!(highlight_id)
    rc = Hermes.remove_employee_project_highlight(personnel_id, project_id, highlight_id)
    employee = Hermes.get_employee!(personnel_id)
    if rc == :ok do
      Hermes.log_user_action(session, %{
        operation: :delete,
        entity: :project_highlight_membership,
        properties: %{
          affects: [Util.take(personnel, [:id, :name, :username])],
          data: %{
            project: Util.take(project, [:id, :title]),
            highlight: Util.take(highlight, [:id, :code, :title])
          }
        }
      })
    end
    employee
  end

  # ----------------------------------------------------------------------------

  @doc """
  Add an employee link to particular project
  """
  @spec link_employee_to_project(
    request_content :: CommonProtocol.Empty.t(),
    personnel_id :: integer,
    project_id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def link_employee_to_project(
    request_content,
    personnel_id,
    project_id,
    session
  ) when
    is_struct(request_content, CommonProtocol.Empty) and
    is_integer(personnel_id) and
    is_integer(project_id)
  do
    unless Hermes.can_link_project?(session, personnel_id, project_id), do: raise DataProtocol.ForbiddenError
    personnel = Hermes.get_employee!(personnel_id)
    project = Hermes.get_project!(project_id)
    rc = Hermes.link_employee_project(personnel_id, project_id)
    employee = Hermes.get_employee!(personnel_id)
    if rc == :ok do
      Hermes.log_user_action(session, %{
        operation: :create,
        entity: :project_membership,
        properties: %{
          affects: [Util.take(personnel, [:id, :name, :username])],
          data: %{
            project: Util.take(project, [:id, :title])
          }
        }
      })
    end
    employee
  end

  # ----------------------------------------------------------------------------

  @doc """
  Remove an employee link to particular project
  """
  @spec unlink_employee_from_project(
    personnel_id :: integer,
    project_id :: integer,
    session :: any()
  ) :: DbProtocol.PersonnelAccount.t()
  @impl true
  def unlink_employee_from_project(
    personnel_id,
    project_id,
    session
  ) when
    is_integer(personnel_id) and
    is_integer(project_id)
  do
    unless Hermes.can_link_project?(session, personnel_id, project_id), do: raise DataProtocol.ForbiddenError
    personnel = Hermes.get_employee!(personnel_id)
    project = Hermes.get_project!(project_id)
    rc = Hermes.unlink_employee_project(personnel_id, project_id)
    employee = Hermes.get_employee!(personnel_id)
    if rc == :ok do
      Hermes.log_user_action(session, %{
        operation: :delete,
        entity: :project_membership,
        properties: %{
          affects: [Util.take(personnel, [:id, :name, :username])],
          data: %{
            project: Util.take(project, [:id, :title])
          }
        }
      })
    end
    employee
  end

  #-----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp log_user_action(session, action, %DbProtocol.PersonnelAccount{id: id} = object) when is_atom(action) do
    Hermes.log_user_action(session, %{
      operation: action,
      entity: :user,
      entity_id: id,
      entity_param: action == :allocate && object.allocated_to_project_name || nil,
      properties: %{data: Util.take(object, [:id, :name, :username, :allocated_to_project_name])}
    })
  end

end
