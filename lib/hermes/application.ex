defmodule Hermes.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("#{__MODULE__} starting")
    children = [
      # Starts a worker by calling: Hermes.Worker.start_link(arg)
      # {Hermes.Worker, arg}
      # start repository
      Repo,
      # start scheduler
      Scheduler,
      # start http endpoint
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: Web.Server,
        # see https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html#module-options
        options: [
          ip: case :inet.parse_address(String.to_charlist(Util.config(:hermes, [:web, :ip], "127.0.0.1"))) do
            {:ok, ip} -> ip
          end,
          port: Util.config(:hermes, [:web, :port]),
          compress: true,
          # NB: Plug punts on websockets by default (?) so we have to provide custom dispatcher
          dispatch: [
            {:_, [
              {"/ws", Web.WebSocket, handler: Web.WebSocket.Impl},
              {:_, Plug.Cowboy.Handler, {Web.Server, []}}
            ]}
          ],
        ]
      ),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hermes.Supervisor]
    link = Supervisor.start_link(children, opts)
    Logger.info("#{__MODULE__} started")
    link
  end
end
