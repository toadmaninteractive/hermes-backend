import Config

# database

config :hermes, Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASS"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST"),
  port: System.get_env("DB_PORT")

# web server

cors_origins = Regex.split(~r{\s*,\s*}, System.fetch_env!("FRONTEND_SERVER_CORS"), trim: true)
config :hermes, :web,
  ip: System.fetch_env!("BACKEND_IP"),
  port: System.fetch_env!("BACKEND_PORT") |> String.to_integer,
  cors: [
    fallback_origin: cors_origins |> List.first,
    allowed_origins: cors_origins
  ],
  session: [
    secret: System.fetch_env!("BACKEND_SESSION_SECRET"),
    encryption_salt: System.fetch_env!("BACKEND_SESSION_ENCRYPTION_SALT"),
    signing_salt: System.fetch_env!("BACKEND_SESSION_SIGNING_SALT")
  ],
  api_keys: System.fetch_env!("BACKEND_API_KEYS") |> String.split(",")

# misc

config :exldap, :settings,
  server: System.fetch_env!("LDAP_HOST"),
  port: System.fetch_env!("LDAP_PORT") |> String.to_integer,
  ssl: System.fetch_env!("LDAP_SSL") === "true",
  sslopts: [verify: :verify_none],
  user_dn: System.fetch_env!("LDAP_USER"),
  password: System.fetch_env!("LDAP_PASS"),
  base: System.fetch_env!("LDAP_BASE")

config :hermes, :access,
  auth_realm: :yourcompany,
  admin_group: System.fetch_env!("BACKEND_ADMIN_GROUP"),
  local_admin: false

config :hermes, :visma,
  # TODO: move to env?
  offices: %{
    "Main" => [
      api_key: "CHANGE_ME"
    ],
  },
  xlsx_generator: System.fetch_env!("BACKEND_XLSX_GENERATOR")
