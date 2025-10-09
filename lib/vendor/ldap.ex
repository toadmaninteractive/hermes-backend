defmodule Auth.Ldap do
  @moduledoc """
  The Auth context.
  """

  require Logger

  defmodule Exception do
    defexception [:message, plug_status: 502]

    @exception_message "Error while talking to LDAP server"

    @impl true
    def exception(error) when is_tuple(error) or is_map(error) do
      exception(inspect(error))
    end
    def exception(error) do
      %__MODULE__{message: "#{@exception_message}: #{error}"}
    end
  end

  # ----------------------------------------------------------------------------

  @type user :: %{dn: String.t(), uid: String.t(), cn: String.t(), mail: String.t(), o: String.t()}
  @type group :: %{dn: String.t(), name: String.t(), members: [String.t()]}

  # ----------------------------------------------------------------------------

  @spec check(String.t(), String.t()) :: {:ok, user} | {:error, :not_found | :invalid_credentials}
  def check(uid, password) when is_binary(uid) and is_binary(password) do
    with_ldap_do(fn ldap ->
      base_users = Util.config!(:exldap, [:settings, :base, :users])
      case Exldap.search_field(ldap, base_users, attr_name(:user_id), uid) do
        {:ok, [%Exldap.Entry{object_name: user_dn} = entry | _]} ->
          case Exldap.verify_credentials(ldap, user_dn, password) do
            :ok -> {:ok, to_user(entry)}
            {:error, :noSuchObject} -> {:error, :not_found}
            {:error, :invalidCredentials} -> {:error, :invalid_credentials}
            {:error, error} -> raise Exception, error
          end
        {:ok, []} -> {:error, :not_found}
        {:error, :noSuchObject} -> {:error, :not_found}
        {:error, error} -> raise Exception, error
      end
    end)
  end

  # ----------------------------------------------------------------------------

  @spec get(String.t()) :: user | nil
  def get(uid) when is_binary(uid) do
    with_ldap_do(fn ldap ->
      base_users = Util.config!(:exldap, [:settings, :base, :users])
      case Exldap.search_field(ldap, base_users, attr_name(:user_id), uid) do
        {:ok, [%Exldap.Entry{} = entry | _]} -> to_user(entry)
        {:ok, []} -> nil
        {:error, :noSuchObject} -> nil
        {:error, error} -> raise Exception, error
      end
    end)
  end

  # ----------------------------------------------------------------------------

  @spec fetch() :: %{users: [user], groups: [group]}
  def fetch() do
    case Util.config!(:exldap, [:settings, :server]) do
      nil -> %{users: [], groups: []}
      _ ->
        with_ldap_do(fn ldap ->
          base_users = Util.config!(:exldap, [:settings, :base, :users])
          user_filter = Exldap.with_and([
            Exldap.equalityMatch(attr_name(:class), attr_name(:class_value_user)),
            Exldap.present(attr_name(:user_id)),
          ])
          users = case Exldap.search_with_filter(ldap, base_users, user_filter) do
            {:ok, list} -> list |> Enum.map(&to_user/1)
            {:error, :noSuchObject} -> []
            {:error, error} -> raise Exception, error
          end
          group_filter = Exldap.with_and([
            Exldap.equalityMatch(attr_name(:class), attr_name(:class_value_group)),
          ])
          base_groups = Util.config!(:exldap, [:settings, :base, :groups])
          groups = case Exldap.search_with_filter(ldap, base_groups, group_filter) do
            {:ok, list} -> list |> Enum.map(&to_group/1)
            {:error, :noSuchObject} -> []
            {:error, error} -> raise Exception, error
          end
          %{users: users, groups: groups}
        end)
    end
  end

  # ----------------------------------------------------------------------------

  @spec users() :: [user]
  def users(), do: Auth.Ldap.fetch().users

  # ----------------------------------------------------------------------------

  @spec groups() :: [group]
  def groups(), do: Auth.Ldap.fetch().groups

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

  defp to_user(%Exldap.Entry{attributes: attrs, object_name: user_dn}) do
    attrs = to_map(attrs)
    # IO.inspect({:u, attrs}, limit: :infinity, pretty: true)
    %{
      dn: unicode(user_dn),
      uid: attr!(attrs, :user_id),
      cn: attr!(attrs, :user_name),
      mail: attr(attrs, :user_email),
      o: attr(attrs, :user_office),
    }
  end

  defp to_group(%Exldap.Entry{attributes: attrs, object_name: group_dn}) do
    attrs = to_map(attrs)
    # IO.inspect({:g, attrs}, limit: :infinity, pretty: true)
    %{
      dn: unicode(group_dn),
      name: attr!(attrs, :group_name),
      members: (attrs[attr_name(:group_members)] || []),
    }
  end

  defp to_map(kv) when is_list(kv) do
    Map.new(kv, fn {k, vs} -> {List.to_string(k), Enum.map(vs, &unicode/1)} end)
  end

  defp unicode(x), do: :binary.list_to_bin(x)

  defp attr_name(keys) when is_list(keys), do: Enum.map(keys, &attr_name/1)
  defp attr_name(key) when is_atom(key), do: Util.config!(:exldap, [:settings, :attr, key])
  defp attr_name(key) when is_binary(key), do: key

  defp attr(_, nil), do: nil
  defp attr(attrs, keys) when is_list(keys), do: Enum.reduce(keys, nil, fn key, acc -> acc || attr(attrs, key) end)
  defp attr(attrs, key) when is_atom(key), do: attr(attrs, attr_name(key))
  defp attr(attrs, key) when is_map(attrs) and is_binary(key) do
    attrs[key] && attr_parse(key, List.first(attrs[key]))
  end

  defp attr_parse(key, attr) when is_binary(key), do: attr

  defp attr!(attrs, key) do
    case attr(attrs, key) do
      nil ->
        Logger.error("LDAP: required attribute #{inspect(attr_name(key))} missing", data: %{key: attr_name(key), attrs: attrs}, domain: :ldap)
        raise Exception, message: "LDAP: required attribute #{inspect(attr_name(key))} missing for cn='#{attrs["cn"]}'"
      x -> x
    end
  end

  defp with_ldap_do(fun) do
    case Exldap.connect() do
      {:ok, ldap} ->
        try do
          fun.(ldap)
        rescue
          e -> raise Exception, e
          # e -> reraise e, __STACKTRACE__
        after
          Exldap.close(ldap)
        end
      {:error, error} -> raise Exception, error
    end
  end

end
