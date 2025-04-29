defmodule Repo.Highlight do
  use Repo.Schema

  schema "highlights" do
    field :rev,             :integer, default: 1
    field :code,            Repo.Types.StringyTrimmedLower
    field :title,           Repo.Types.StringyTrimmed

    timestamps()
  end

  # ----------------------------------------------------------------------------
  # api
  # ----------------------------------------------------------------------------

  use Repo.Entity, repo: Repo

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

  @doc false
  def insert_changeset(attrs) do
    import Ecto.Changeset
    %__MODULE__{}
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [nil, ""])
      |> require_presence(~w(code title)a)
      |> check_constraints([
        code: "code_can_not_be_empty",
        title: "title_can_not_be_empty",
      ])
      |> unique_constraints([
        code: "highlights_code_index",
        code: "highlights_code_ult_index",
        title: "highlights_title_index",
        title: "highlights_title_ult_index",
      ])
  end

  @doc false
  def update_changeset(orig, attrs) do
    import Ecto.Changeset
    orig
      |> cast(Enum.into(attrs, %{}), __schema__(:fields), empty_values: [])
      |> require_presence(~w(code title)a)
      |> check_constraints([
        code: "code_can_not_be_empty",
        title: "title_can_not_be_empty",
      ])
      |> unique_constraints([
        code: "highlights_code_index",
        code: "highlights_code_ult_index",
        title: "highlights_title_index",
        title: "highlights_title_ult_index",
      ])
  end

  # ----------------------------------------------------------------------------

end
