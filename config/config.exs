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
  level: :warn,
  level: config_env() == :prod && :warn || :info,
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
    sync_ldap: [schedule: "*/27 * * * *", task: {Hermes, :sync_ldap, []}, overlap: false],
    sync_timeoffs: [schedule: "*/13 * * * *", task: {Hermes, :sync_timeoffs, []}, overlap: false],
    prolong_user_assignment: [schedule: "00 01 * * 1-5", task: {Hermes, :prolong_user_assignment, []}, overlap: false],
  ]

#
# web server
#

config :plug_cowboy,
  log_exceptions_with_status_code: []

config :hermes, :web,
  session: [
    store: :cookie,
    key: "hsid",
    secret: "TODO: place to BACKEND_SESSION_SECRET environment",
    encryption_salt: "TODO: place to BACKEND_SESSION_ENCRYPTION_SALT environment",
    signing_salt: "TODO: place to BACKEND_SESSION_SIGNING_SALT environment",
    key_length: 64,
    max_age: 365 * 86400,
    log: false
  ],
  websocket: [
    heartbeat: 55000
  ]

#
# private portion
#

config :exldap, :settings,
  search_timeout: 5000

config :hermes, :access,
  auth_realm: :yourcompany,
  admin_group: "admins",
  local_admin: false

config :hermes, :bamboo,
  main: [
    base_url: "https://api.bamboohr.com/api/gateway.php",
    company_domain: "yourcompany",
    api_key: "CHANGE_ME",
    timeoffs: %{
      "83"  => :paid_vacation,
      "85"  => :time_off,
      "87"  => :sick,
      "90"  => :parental_leave,
      "91"  => :vab,
      "93"  => :holiday,
    },
  ]

config :hermes, :visma,
  offices: %{
    "Main" => [
      api_key: "CHANGE_ME"
    ],
  }

config :hermes, :junipeer,
  url: "https://api.junipeer.io/yourcompany",
  username: "CHANGE_ME",
  password: "CHANGE_ME"

config :hermes, :hrvey,
  url: "https://www.hrvey.com",
  email: "apiuser@yourcompany.com",
  password: "CHANGE_ME",
  timeoffs: %{
    "Vacation" => :paid_vacation,
    "Sick leave" => :sick,
    "Paid leave" => :paid_vacation,
    "Unpaid leave" => :unpaid_vacation,
    "Maternity leave" => :maternity_leave,
    "Paternity leave" => :parental_leave,
  }

#
# environment specific config
#
import_config "#{config_env()}.exs"
