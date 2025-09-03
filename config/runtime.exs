import Config

# merge json config

#conf = File.read!(System.get_env("CONFIG_PATH", "config.json")) |> Jason.decode!(keys: :atoms)
conf = System.get_env("CONFIG_PATH", "config.yaml")
  |> YamlElixir.read_from_file!()
  |> Map.get("hermes")
  |> ConfigProtocol.Config.from_json!()

  # TODO?: is protocol capable of parsing record into keyword list?
  |> Map.from_struct()
  |> Enum.map(fn
    {k, v} when is_struct(v) -> {k, v |> Map.from_struct() |> Map.to_list()}
    {k, v} when is_map(v) -> {k, v |> Map.to_list()}
    {k, v} -> {k, v}
  end)
  |> update_in([:web, :session], & &1 |> Map.from_struct() |> Map.to_list())
  |> IO.inspect(label: "CONF")

# database

config :hermes, Repo, conf[:db]

# web server

config :hermes, :web, conf[:web]

# misc

config :exldap, :settings, conf[:ldap]

config :hermes, :access, conf[:access]
config :hermes, :bamboo, conf[:bamboo]
config :hermes, :visma, conf[:visma]
config :hermes, :junipeer, conf[:junipeer]
config :hermes, :hrvey, conf[:hrvey]
