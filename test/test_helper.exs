ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

defmodule Web.Test do

  use Plug.Test
  use ExUnit.Case, async: true

  def request(method, path, body, opts) do
    conn = conn(method, path, Jason.encode!(body))
    conn = case Keyword.get(opts, :session, true) do
      true -> conn |> init_test_session(%{api: %{user_id: 178, name: "Vasya Pupkin", username: "vasya.pupkin"}})
      false -> conn
    end
    conn = conn
      |> put_req_header("content-type", "application/json; charset=utf-8")
      |> Web.Server.call(Web.Server.init([]))
    # if conn.status == 500 do
    #   IO.inspect(conn)
    # end
    assert conn.state == :sent
    assert conn.status == Keyword.get(opts, :status, 200)
    assert Plug.Conn.get_resp_header(conn, "content-type") === ["application/json; charset=utf-8"]
    Jason.decode!(conn.resp_body, keys: :atoms)
  end

  def get(path, opts \\ []) do
    request :get, path, nil, opts
  end

  def post(path, data, opts \\ []) do
    request :post, path, data, opts
  end

  def put(path, data, opts \\ []) do
    request :put, path, data, opts
  end

  def delete(path, opts \\ []) do
    request :delete, path, nil, opts
  end

end
