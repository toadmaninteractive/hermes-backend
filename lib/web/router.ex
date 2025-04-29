defmodule Web.Router do
  @moduledoc """
  HTTP Server Router
  """

  use Plug.Router
  if Mix.env == :dev, do: use Plug.Debugger
  use Plug.ErrorHandler

  plug :match
  if Mix.env != :test do
    plug :authenticate
  end
  plug :dispatch

  # --- START of routes --------------------------------------------------------

  use WebProtocol.HermesAuthService.Impl, :router
  use WebProtocol.HermesAdminService.Impl, :router
  use WebProtocol.HermesDirectoryService.Impl, :router
  use WebProtocol.HermesEmployeeService.Impl, :router
  use WebProtocol.HermesHighlightService.Impl, :router
  use WebProtocol.HermesHistoryService.Impl, :router
  use WebProtocol.HermesOfficeService.Impl, :router
  use WebProtocol.HermesProjectService.Impl, :router
  use WebProtocol.HermesReportService.Impl, :router
  use WebProtocol.HermesRoleService.Impl, :router
  use WebProtocol.HermesTaskService.Impl, :router
  use WebProtocol.HermesTeamService.Impl, :router
  use WebProtocol.HermesTimesheetService.Impl, :router
  use WebProtocol.HermesVismaService.Impl, :router

  # --- END of routes ----------------------------------------------------------

  # catchall route
  match _ do
    send_resp(conn, 404, "")
  end

  #-----------------------------------------------------------------------------
  # middleware
  #-----------------------------------------------------------------------------

  def authenticate(%{assigns: %{auth_by_api_key: true}} = conn, opts) do
    # TODO: FIXME: de-hardcode api key header name
    if get_req_header(conn, "x-api-key") != [] do
      conn
    else
      authenticate(assign(conn, :auth_by_api_key, nil), opts)
    end
  end
  def authenticate(%{assigns: %{session: session}} = conn, _opts) do
    # TODO: improve or replace database consulting
    if !session or !Repo.Session.get(session.key) do
      if conn.assigns[:auth] == false do
        conn
          |> delete_session(:api)
      else
        conn
          |> delete_session(:api)
          |> put_resp_header("www-authenticate", "interactive login")
          |> send_resp(401, "")
          |> halt
      end
    else
      conn
    end
  end

  #-----------------------------------------------------------------------------
  # internal functions
  #-----------------------------------------------------------------------------

  defp handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack} = error) do
    case reason do
      _ ->
        require Logger
        Logger.error(error)
        conn
          |> send_resp(conn.status, "")
    end
  end

end
