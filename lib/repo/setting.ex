defmodule Repo.Setting do
  use Repo.Schema

  @primary_key false
  schema "settings" do
    field :name,            Repo.Types.StringyTrimmedLower, primary_key: true
    field :type,            Ecto.Enum, values: [:string, :int, :float, :bool]
    field :value,           Repo.Types.Stringy

    timestamps()
  end

  # ----------------------------------------------------------------------------
  # api
  # ----------------------------------------------------------------------------

  use Repo.Entity, repo: Repo

  def to_map() do
    all(order_by: [:name])
      |> Enum.map(& {String.to_atom(&1.name), convert(&1.type, &1.value)})
      |> Enum.into(%{})
  end

  def update(%{} = patch) do
    all([])
      |> Enum.map(&
        case patch[String.to_atom(&1.name)] do
          nil -> :ok
          v -> update(&1, value: v)
        end
      )
  end

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

  @doc false
  def insert_changeset(attrs) do
    import Ecto.Changeset
    %__MODULE__{}
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [nil, ""])
      |> require_presence(~w(name type value)a)
      |> check_constraints([
      ])
      |> check_foreign_constraints([
      ])
      |> unique_constraints([
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence(~w(name type value)a)
      |> check_constraints([
      ])
      |> check_foreign_constraints([
      ])
      |> unique_constraints([
      ])
  end

  # ----------------------------------------------------------------------------

  defp convert(:string, value) when is_binary(value), do: value
  defp convert(:int, value) when is_binary(value), do: String.to_integer(value)
  defp convert(:float, value) when is_binary(value), do: String.to_float(value)
  defp convert(:bool, "true"), do: true
  defp convert(:bool, "false"), do: false

end
