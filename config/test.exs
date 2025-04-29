import Config

# logger
config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :warning],
  ]

# database
config :hermes, Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  url: "ecto://postgres:postgres@localhost/hermes_test"

# scheduler
config :hermes, Scheduler,
  debug_logging: false,
  overlap: false,
  jobs: []

# web server
config :hermes, :web,
  port: 39102
