defmodule Auth.Ldap do
  @moduledoc """
  The Auth context.
  """

  alias Exldap

  require Logger

  # ----------------------------------------------------------------------------

  @type user :: %{cn: String.t(), dn: String.t(), mail: String.t(), o: String.t(), uid: String.t()}
  @type group :: %{name: String.t(), members: [String.t()]}

  # ----------------------------------------------------------------------------

  @spec check(String.t(), String.t()) ::
          {:ok, user} | {:error, :account_not_exists | :failure | :wrong_password}
  def check(username, password) when is_binary(username) and is_binary(password) do
    with_ldap_do(fn ldap ->
      base = Application.get_env(:exldap, :settings)[:base]
      case Exldap.search_field(ldap, "ou=users,#{base}", "uid", username) do
        {:ok, [%Exldap.Entry{attributes: attrs, object_name: user_dn} | _]} ->
          case Exldap.verify_credentials(ldap, user_dn, password) do
            :ok ->
              user = Util.take(to_map(attrs), [
                cn: [:cn, 0],
                dn: fn _ -> unicode(user_dn) end,
                mail: [:mail, 0],
                o: [:o, 0],
                uid: [:uid, 0],
              ])
              {:ok, user}
            {:error, :noSuchObject} -> {:error, :account_not_exists}
            {:error, :invalidCredentials} -> {:error, :wrong_password}
            {:error, _reason} -> {:error, :failure}
          end
        {:ok, []} -> {:error, :account_not_exists}
        {:error, :noSuchObject} -> {:error, :account_not_exists}
        {:error, _reason} -> {:error, :failure}
      end
    end)
  end

  # ----------------------------------------------------------------------------

  @spec get(String.t()) :: {:ok, user} | {:error, :account_not_exists | :failure | :wrong_password}
  def get(username) when is_binary(username) do
    with_ldap_do(fn ldap ->
      base = Application.get_env(:exldap, :settings)[:base]
      case Exldap.search_field(ldap, "ou=users,#{base}", "uid", username) do
        {:ok, [%Exldap.Entry{attributes: attrs, object_name: user_dn} | _]} ->
          user = Util.take(to_map(attrs), [
            cn: [:cn, 0],
            dn: fn _ -> unicode(user_dn) end,
            mail: [:mail, 0],
            o: [:o, 0],
            uid: [:uid, 0],
          ])
          {:ok, user}
        {:ok, []} -> {:error, :account_not_exists}
        {:error, :noSuchObject} -> {:error, :account_not_exists}
        {:error, :unwillingToPerform} -> {:error, :failure}
        {:error, :invalidCredentials} -> {:error, :failure}
      end
    end)
  end

  # ----------------------------------------------------------------------------

  @spec users() :: {:ok, [user]} | {:error, :account_not_exists | :failure | :wrong_password}
  def users() do
    with_ldap_do(fn ldap ->
      base = Application.get_env(:exldap, :settings)[:base]
      filter = Exldap.present("uid")
      case Exldap.search_with_filter(ldap, base, filter) do
        {:ok, list} ->
          list = list
            |> Enum.map(fn %Exldap.Entry{attributes: attrs, object_name: user_dn} ->
              Util.take(to_map(attrs), [
                cn: [:cn, 0],
                dn: fn _ -> unicode(user_dn) end,
                mail: [:mail, 0],
                o: [:o, 0],
                uid: [:uid, 0],
              ])
            end)
          {:ok, list}
        {:error, :noSuchObject} -> {:error, :account_not_exists}
        {:error, _reason} -> {:error, :failure}
      end
    end)
  end

  # ----------------------------------------------------------------------------

  @spec groups() :: {:ok, [group]} | {:error, :account_not_exists | :failure | :wrong_password}
  def groups() do
    with_ldap_do(fn ldap ->
      base = Application.get_env(:exldap, :settings)[:base]
      filter = Exldap.with_or([Exldap.present("member"), Exldap.present("uniqueMember")])
      case Exldap.search_with_filter(ldap, base, filter) do
        {:ok, list} ->
          list = list
            |> Enum.map(fn %Exldap.Entry{attributes: attrs, object_name: _user_dn} ->
              Util.take(to_map(attrs), [name: [:cn, 0], members: :member])
            end)
          {:ok, list}
        {:error, :noSuchObject} -> {:error, :account_not_exists}
        {:error, _reason} -> {:error, :failure}
      end
    end)
  end

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

  defp to_map(kv) when is_list(kv) do
    Map.new(kv, fn
      {k, vs} -> {List.to_atom(k), Enum.map(vs, &unicode/1)}
    end)
  end

  defp unicode(x) do
    :binary.list_to_bin(x)
  end

  defp with_ldap_do(fun) do
    case Exldap.connect() do
      {:ok, ldap} ->
        try do
          fun.(ldap)
        after
          Exldap.close(ldap)
        end
      {:error, _reason} -> {:error, :failure}
    end
  end

end
