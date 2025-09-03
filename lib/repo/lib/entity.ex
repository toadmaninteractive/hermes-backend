defmodule Repo.Entity do

  @callback insert_changeset(Access.t) :: Ecto.Changeset.t
  @callback update_changeset(Struct.t, Access.t) :: Ecto.Changeset.t

  import Util.Guards

  defmacro __using__(options \\ []) do
    quote generated: true, location: :keep do
      @behaviour Repo.Entity
      import Util.Guards
      alias unquote(options[:repo])

      # ------------------------------------------------------------------------

      @spec get(id :: Integer.t) :: %__MODULE__{} | nil

      def get(pk) do
        Repo.get(__MODULE__, pk)
      end

      # ------------------------------------------------------------------------

      @spec one!(criteria :: Access.t) :: %__MODULE__{} | nil | no_return

      def one!(criteria) when is_access(criteria) do
        filter(criteria)
          |> Repo.one!()
      end

      # ------------------------------------------------------------------------

      @spec all(criteria :: Access.t | Ecto.Query.t) :: [%__MODULE__{}]

      def all(criteria \\ [])
      def all(criteria) when is_access(criteria) do
        filter(criteria)
          |> all()
      end
      def all(query) do
        query
          |> Repo.all()
      end

      # ------------------------------------------------------------------------

      @spec count(criteria :: Access.t) :: Integer.t

      def count(criteria \\ []) when is_access(criteria) do
        import Ecto.Query
        filter(criteria)
          |> select(fragment("COUNT(*)"))
          |> Repo.one()
      end

      # ------------------------------------------------------------------------

      @spec exists?(criteria :: Access.t) :: true | false

      def exists?(criteria) when is_access(criteria) do
        filter(criteria)
          |> Repo.exists?()
      end

      # ------------------------------------------------------------------------

      @spec insert(fields :: Map.t, opts :: Keyword.t) :: {:ok, Ecto.Schema.t} | {:error, Atom.t}

      def insert(fields, opts \\ []) when is_map(fields) and is_list(opts) do
        insert_changeset(fields)
          |> Repo.insert(opts)
          |> case do
            {:ok, record} ->
              {:ok, record}
            {:error, %Ecto.Changeset{valid?: false, errors: [{field, {"is invalid", _}} | _]} = x} ->
              {:error, String.to_atom("invalid_#{field}")}
            {:error, %Ecto.Changeset{valid?: false, errors: [{_field, {error, _}} | _]} = x} ->
              {:error, String.to_atom(error)}
          end
      end

      @spec insert!(fields :: Map.t, opts :: Keyword.t) :: Ecto.Schema.t | no_return()

      def insert!(fields, opts \\ []) when is_map(fields) and is_list(opts) do
        case insert(fields, opts) do
          {:ok, record} -> record
          # {:error, error} -> raise DataProtocol.BadRequest, error: error
        end
      end

      # ------------------------------------------------------------------------

      @spec update(struct :: Ecto.Schema.t | Ecto.Changeset.t, patch :: Access.t) :: {:ok, Ecto.Schema.t} | {:error, Atom.t}

      def update(struct, patch) when is_struct(struct) and is_access(patch) do
        import Ecto.Changeset
        struct
          |> update_changeset(patch)
          |> case do
            %{valid?: true, data: data, changes: changes} = changeset ->
              changeset = case Map.has_key?(data, :rev) and not Enum.empty?(changes) do
                true -> changeset |> put_change(:rev, data.rev + 1)
                false -> changeset
              end
            changeset ->
              changeset
          end
          |> Repo.update
          |> case do
            {:ok, record} ->
              {:ok, record}
            {:error, %Ecto.Changeset{valid?: false, errors: [{_field, {error, _}} | _]}} = x ->
              {:error, String.to_atom(error)}
          end
      end

      defp do_update(criteria, changes) when is_access(criteria) do
        do_update(filter(criteria), changes)
      end
      defp do_update(query, changes) do
        case Repo.update_all(
          query,
          set: Map.to_list(changes),
          set: __schema__(:type, :updated_at) && [updated_at: DateTime.utc_now] || [],
          inc: (__schema__(:type, :rev) != nil and changes[:rev] == nil) && [rev: 1] || []
        ) do
          {0, _} -> {:error, :not_exists}
          {_, nil} -> :ok
          {_, r} -> {:ok, r}
        end
      rescue
        e in Postgrex.Error ->
          case e do
            %{postgres: %{code: code, detail: detail}} ->
              {:error, {code, detail}}
          end
      end

      @spec update_many(Access.t | Ecto.Query.t, changes :: Access.t) :: :ok | {:ok, [Ecto.Schema.t]} | {:error, reason :: any}
      def update_many(criteria, changes) when is_access(changes) do
        case do_update(criteria, changes) do
          # TODO: think whether {:error, :not_exists} should be error in case of update?
          x -> x
        end
      end

      # ------------------------------------------------------------------------

      @spec delete(struct :: Ecto.Schema.t | Ecto.Changeset.t) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}

      def delete(struct) when is_struct(struct) do
        struct
          |> Repo.delete
          |> case do
            {0, _} -> {:error, :not_exists}
            {_n, _} -> :ok
          end
      end

      @spec delete_many(criteria :: Access.t) :: :ok | {:error, reason :: any}

      def delete_many(criteria) when is_access(criteria) do
        Enum.empty?(criteria) && raise ArgumentError, message: "criteria can not be empty"
        filter(criteria)
          |> Repo.delete_all
          |> case do
            {0, _} -> {:error, :not_exists}
            {_n, _} -> :ok
          end
      end

      # ------------------------------------------------------------------------

      @spec join(relation :: Atom.t, relation_id :: any, criteria :: Access.t)
            :: [:ok | {:error, reason :: Atom.t}]

      def join(relation, relation_id, criteria) when is_atom(relation) and is_access(criteria) do
        case __schema__(:association, relation) do
          %Ecto.Association.BelongsTo{cardinality: :one, owner_key: key, relationship: :parent} ->
            update(criteria, [{key, relation_id}])
          %Ecto.Association.ManyToMany{
            cardinality: :many,
            join_through: join_through,
            join_keys: [{self_pk, self_id}, {relation_pk, _}],
            relationship: :child
          } ->
            filter(criteria)
              |> Repo.all()
              |> Enum.map(fn self ->
                id = Map.get(self, self_id)
                Repo.query("INSERT INTO #{join_through} (#{self_pk}, #{relation_pk}) VALUES ($1, $2)", [id, relation_id])
              end)
              |> Enum.map(fn
                {:ok, _} -> :ok
                {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} -> {:error, :already_exists}
                {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}} -> {:error, :not_exists}
              end)
        end
      end

      # ------------------------------------------------------------------------

      @spec leave(relation :: Atom.t, relation_id :: any, criteria :: Access.t)
            :: [:ok | {:error, reason :: Atom.t}]

      def leave(relation, relation_id, criteria) when is_atom(relation) and is_access(criteria) do
        case __schema__(:association, relation) do
          %Ecto.Association.BelongsTo{cardinality: :one, owner_key: key, relationship: :parent} ->
            # NB: direct update to nilify the field
            do_update(criteria, %{key => nil})
          %Ecto.Association.ManyToMany{
            cardinality: :many,
            join_through: join_through,
            join_keys: [{self_pk, self_id}, {relation_pk, _}],
            relationship: :child
          } ->
            filter(criteria)
              |> Repo.all()
              |> Enum.map(fn self ->
                id = Map.get(self, self_id)
                Repo.query("DELETE FROM #{join_through} WHERE #{self_pk} = $1 AND #{relation_pk} = $2", [id, relation_id])
              end)
              |> Enum.map(fn
                {:ok, %Postgrex.Result{num_rows: 1}} -> :ok
                {:ok, %Postgrex.Result{num_rows: 0}} -> {:error, :not_exists}
              end)
        end
      end

      # ------------------------------------------------------------------------

      @spec is_member?(relation :: Atom.t, relation_id :: any, criteria :: Access.t)
            :: [true | false]

      def is_member?(relation, relation_id, criteria) when is_atom(relation) and is_access(criteria) do
        case __schema__(:association, relation) do
          %Ecto.Association.BelongsTo{cardinality: :one, owner_key: key, relationship: :parent} ->
            all(criteria) |> Enum.map(& Map.get(&1, key) == relation_id)
          %Ecto.Association.ManyToMany{
            cardinality: :many,
            join_through: join_through,
            join_keys: [{self_pk, self_id}, {relation_pk, _}],
            relationship: :child
          } ->
            all(criteria) |> Enum.map(fn x ->
              case Repo.query("SELECT (count(*) > 0)::boolean FROM #{join_through} WHERE #{self_pk} = $1 AND #{relation_pk} = $2", [x.id, relation_id]) do
                {:ok, %{rows: [[true]]}} -> true
                _ -> false
              end
            end)
            # Repo.query("SELECT (count(*) > 0)::boolean FROM #{join_through} WHERE #{self_pk} = ANY($1) AND #{relation_pk} = $2", [ids, relation_id])
        end
      end

      # ------------------------------------------------------------------------

      def for_all(criteria \\ []) when is_access(criteria) do
        filter(criteria)
      end

      # ------------------------------------------------------------------------

      defp filter(criteria \\ [], query \\ __MODULE__) when is_access(criteria) do
        import Ecto.Query
        {query, criteria} = case Access.pop(criteria, :order_by) do
          {nil, _} ->
            {query, criteria}
          {order_by, criteria} ->
            {query |> order_by(^order_by), criteria}
        end
        {query, criteria} = case Access.pop(criteria, :offset) do
          {nil, _} ->
            {query, criteria}
          {offset, criteria} ->
            {query |> offset(^offset), criteria}
        end
        {query, criteria} = case Access.pop(criteria, :limit) do
          {nil, _} ->
            {query, criteria}
          {limit, criteria} ->
            {query |> limit(^limit), criteria}
        end
        {query, criteria} = case Access.pop(criteria, :preload) do
          {nil, _} ->
            {query, criteria}
          {preload, criteria} ->
            {query |> preload(^preload), criteria}
        end
        {query, criteria} = case Access.pop(criteria, :select) do
          {nil, _} ->
            {query, criteria}
          {select, criteria} ->
            {query |> select(^select), criteria}
        end
        {query, criteria} = case __schema__(:primary_key) do
          [pk] -> case Access.pop(criteria, pk) do
            {nil, _} ->
              {query, criteria}
            {pks, criteria} when is_list(pks) ->
              {query |> where([x], field(x, ^pk) in ^pks), criteria}
            {pks, criteria} ->
              {query |> where([x], field(x, ^pk) in ^[pks]), criteria}
          end
          _ -> {query, criteria}
        end
        Enum.reduce(criteria, query, fn {k, v}, query ->
          case v do
            nil -> query
            _ ->
              case __schema__(:type, k) do
                :id ->
                  v = is_list(v) && v || [v]
                  query |> where([x], field(x, ^k) in ^v)
                :boolean ->
                  query |> where([x], field(x, ^k) == ^v)
                :integer ->
                  query |> where([x], field(x, ^k) == ^v)
                :naive_datetime when is_list(v) ->
                  [v1, v2] = v
                  query |> where([x], fragment("? BETWEEN ? AND ?", field(x, ^k), ^v1, ^v2))
                :naive_datetime ->
                  query |> where([x], field(x, ^k) == ^v)
                {:parameterized, Ecto.Enum, _} ->
                  query |> or_where([x], field(x, ^k) == ^v)
                # :map ->
                #   query |> or_where([x], field(x, ^k) == ^v)
                _ ->
                  query |> or_where([x], ilike(field(x, ^k), ^v))
# # TODO: below
# # "WHERE strpos(lower(k), LOWER($1)) > 0"
#                   v = "%#{v}%"
#                   query |> or_where([x], ilike(field(x, ^k), ^v))
              end
          end
        end)
      end

      # ------------------------------------------------------------------------

      defp require_presence(changeset, fields) when is_list(fields) do
        fields |> Enum.reduce(changeset, fn field, changeset ->
          changeset |> Ecto.Changeset.validate_required(field, message: "invalid_#{field}")
        end)
      end

      defp check_constraints(changeset, constraints) when is_list(constraints) do
        constraints |> Enum.reduce(changeset, fn {field, constraint_name}, changeset ->
          changeset |> Ecto.Changeset.check_constraint(field, name: constraint_name, message: "invalid_#{field}")
        end)
      end

      defp check_foreign_constraints(changeset, constraints) when is_list(constraints) do
        constraints |> Enum.reduce(changeset, fn {field, constraint_name}, changeset ->
          field_name_without_id = to_string(field) |> String.replace_trailing("_id", "")
          changeset |> Ecto.Changeset.foreign_key_constraint(field, name: constraint_name, message: "#{field_name_without_id}_not_exists")
        end)
      end

      defp unique_constraints(changeset, constraints) when is_list(constraints) do
        constraints |> Enum.reduce(changeset, fn {field, constraint_name}, changeset ->
          changeset |> Ecto.Changeset.unique_constraint(field, name: constraint_name, message: "#{field}_already_exists")
        end)
      end

      # ------------------------------------------------------------------------

    end

  end

end
