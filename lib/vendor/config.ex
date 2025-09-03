defmodule JSONConfigProvider do
  @behaviour Config.Provider

  @impl true
  def init(path) when is_binary(path), do: path

  @impl true
  def load(config, path) do
    {:ok, _} = Application.ensure_all_started(:jason)

    json = path |> File.read!() |> Jason.decode!(keys: :atoms)

    Config.Reader.merge(
      config,
      json
      #hermes: [
      #  some_value: json["my_app_some_value"],
      #  another_value: json["my_app_another_value"],
      #]
    )
  end
end
