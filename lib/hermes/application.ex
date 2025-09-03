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
      {Bandit,
        plug: Web.Server,
        ip: case :inet.parse_address(String.to_charlist(Util.config!(:hermes, [:web, :ip]))) do
          {:ok, ip} -> ip
        end,
        port: Util.config!(:hermes, [:web, :port]),
      },
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hermes.Supervisor]
    link = Supervisor.start_link(children, opts)
    Logger.info("#{__MODULE__} started")
    link
  end
end
