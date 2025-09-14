import Config

#
# logger
#

config :logger,
  backends: [
    :console,
    {LoggerFileBackend, :error_log}
  ],
  compile_time_purge_matching: [
  ]

config :logger, :console,
  level: :warning,
  level: config_env() == :prod && :warning || :info,
  metadata: [:domain, :data, :request_id],
  format: {Logger.Formatter.Vd, :format},
  truncate: :infinity

config :logger, :error_log,
  path: "log/error.txt",
  rotate: %{max_bytes: 10000000, keep: 10},
  level: :error,
  format: {Logger.Formatter.Vd, :format},
  metadata: [:domain, :data, :request_id]

#
# database
#

config :hermes,
  ecto_repos: [Repo]

config :hermes, Repo,
  # migration_primary_key: [type: :binary_id],
  migration_timestamps: [inserted_at: :created_at],
  timeout: 30000,
  show_sensitive_data_on_connection_error: false,
  pool_size: 10,
  queue_target: 5000,
  parameters: [
    application_name: "hermes-#{config_env()}",
  ],
  log: false

#
# scheduler
#

config :hermes, Scheduler,
  debug_logging: false,
  overlap: false,
  jobs: [
    migrate: [schedule: "@reboot", task: {Repo, :migrate, []}],
    sync_ldap: [schedule: "*/10 * * * *", task: {Hermes, :sync_ldap, []}, overlap: false],
    # sync_timeoffs: [schedule: "*/13 * * * *", task: {Hermes, :sync_timeoffs, []}, overlap: false],
    prolong_user_assignment: [schedule: "00 01 * * 1-5", task: {Hermes, :prolong_user_assignment, []}, overlap: false],
  ]

#
# web server
#

config :hermes, :web,
  session: [
    store: :cookie,
    key: "hsid",
    signing_salt: "TODO: specify in runtime config",
    key_length: 64,
    max_age: 365 * 86400,
    log: false
  ]

#
# private portion
#

config :exldap, :settings,
  sslopts: [verify: :verify_none],
  search_timeout: 5000

#
# environment specific config
#
import_config "#{config_env()}.exs"
