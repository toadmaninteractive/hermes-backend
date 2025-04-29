defmodule Util do

  # ----------------------------------------------------------------------------
  # common helpers
  # ----------------------------------------------------------------------------

  @spec obj(Access.t(), nonempty_list(node) | atom, term) :: term
  def obj(data, keys, default \\ nil)
  def obj(nil, _keys, default), do: default
  def obj(data, key, default) when is_atom(key) do
    get_in(data, [Access.key(key, default)])
  end
  # def obj(data, :map, default) do
  #   Enum.map(data, key, default)
  # end
  def obj(data, key, default) when is_integer(key) do
    Enum.at(data, key, default)
  end
  def obj(data, [], default) do
    data || default
  end
  def obj(data, [key | keys], default) do
    obj(data, key) |> obj(keys, default)
  end

  def take(rec, nil), do: rec
  def take(rec, props) do
    Enum.map(props, fn
      k when is_atom(k) -> {k, obj(rec, k)}
      {k, fun} when is_function(fun) -> {k, fun.(rec)}
      {k, p} -> {k, obj(rec, p)}
    end) |> Enum.into(%{})
  end

  def take(rec, type, props) do
    struct!(type, take(rec, props))
  end

  def trimmed(nil), do: nil
  def trimmed(x) when is_binary(x), do: x |> String.trim()
  def trimmed_lower(nil), do: nil
  def trimmed_lower(x) when is_binary(x), do: x |> trimmed() |> String.downcase()

  # pipe-friendly struct constructor
  def to_struct!(obj, struct_name), do: struct!(struct_name, obj)

  # deep-nested map field setter
  def set(map, path, value) when is_list(path) do
    put_in(map, Enum.map(path, &Access.key(&1, %{})), value)
  end

  def config(app, [key | path], default \\ nil) do
    Enum.reduce(path, Application.get_env(app, key), fn step, acc -> acc[step] end) || default
  end

  # ----------------------------------------------------------------------------
  # internal functions
  # ----------------------------------------------------------------------------

end

defmodule Util.Guards do

  defguard is_access(x) when is_list(x) or is_map(x) and not is_struct(x)
  defguard is_key(x) when (is_binary(x) and x != "") or (is_atom(x) and x != nil)

end

defmodule Util.Date do

  defguard is_date(value) when is_struct(value, Date)

  @spec to_json!(Date.t()) :: String.t()
  def to_json!(%Date{} = value), do: Date.to_iso8601(value)
  @spec from_json!(String.t()) :: Date.t()
  def from_json!(value) when is_binary(value), do: Date.from_iso8601!(value)

  @spec to_string!(Date.t()) :: String.t()
  def to_string!(%Date{} = value), do: to_json!(value)
  @spec from_string!(String.t()) :: Date.t()
  def from_string!(value) when is_binary(value), do: from_json!(value)

  # TODO: library?
  def start_of_day(date \\ NaiveDateTime.utc_now()) do
    {d, _} = NaiveDateTime.to_erl(date)
    date = NaiveDateTime.from_erl!({d, {0, 0, 0}})
    date
  end

  @spec to_naive!(Date.t()) :: NaiveDateTime.t()
  def to_naive!(date) do
    NaiveDateTime.new!(date, ~T(00:00:00))
  end

  @spec from_naive!(NaiveDate.t()) :: DateTime.t()
  def from_naive!(date) do
    DateTime.from_naive! date, "Etc/UTC"
  end

  def week_number(date) do
    {_year, week} = :calendar.iso_week_number(Date.to_erl(date))
    week
  end

  def split_to_years(%{year: y1}, %{year: y2}) do
    y1..y2 |> Enum.map(& &1)
  end

  def split_to_months(dates) do
    dates
      |> Enum.reduce(%{}, fn date, acc ->
        %{year: year, month: month, day: day} = date
        acc
          |> Util.set([{year, month}, day], true)
      end)
      |> Enum.map(fn {{year, month}, days} ->
        %{year: year, month: month, days: Map.keys(days)}
      end)
  end

  def split_to_months(date1, date2) do
    Date.range(date1, date2) |> split_to_months()
  end

end

defmodule Util.DateTime do

  defguard is_date_time(value) when is_struct(value, NaiveDateTime)

  @spec to_json!(DateTime.t() | NaiveDateTime.t()) :: String.t()
  def to_json!(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def to_json!(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value) <> "Z"
  @spec from_json!(String.t()) :: NaiveDateTime.t()
  def from_json!(value) when is_binary(value), do: NaiveDateTime.from_iso8601!(value)

  @spec to_string!(DateTime.t()) :: String.t()
  def to_string!(%DateTime{} = value), do: to_json!(value)
  @spec from_string!(String.t()) :: DateTime.t()
  def from_string!(value) when is_binary(value), do: from_json!(value)

  def now, do: NaiveDateTime.utc_now |> to_json!

end

defmodule Util.Map do

  def flatten(map) when is_map(map) do
    map
      |> to_list_of_tuples
      |> Enum.into(%{})
  end

  defp to_list_of_tuples(m) do
    m
      |> Enum.map(&process/1)
      |> List.flatten
  end

  defp process({key, sub_map}) when is_map(sub_map) do
    for {sub_key, value} <- flatten(sub_map) do
      {"#{key}.#{sub_key}", value}
    end
  end

  defp process(next), do: next

end

defmodule Util.Types do

  def collect_errors(%Ecto.Changeset{valid?: false} = validation) do
IO.inspect({:ce, validation.errors})
    Ecto.Changeset.traverse_errors(validation, fn _, name, {msg, opts} ->
      # case opts do
      #   [validation: :required] ->
      #     "missing"
      #   [type: type, validation: :cast] ->
      #      "must be #{json_type(type)}"
      #   [validation: :embed, type: type] ->
      #     "must be #{json_type(type)}"
      # end
      cerr(name, {msg, opts})
    end)
    # |> Util.Map.flatten
    # |> Enum.map(fn
    #   {"content_request." <> k, v} -> {"body.#{k}", Enum.join(v, ", ")}
    #   {"content_request", v} -> {"body", Enum.join(v, ", ")}
    #   {k, v} -> {k, Enum.join(v, ", ")}
    # end)
    # |> Enum.into(%{})
  end

  defp cerr(name, {msg, opts}) do
    case opts do
      [{:validation, :required} | _] ->
        %{name => "missing"}
      [{:type, type}, {:validation, :cast} | _] ->
        cond do
          is_list(msg) -> msg |> Enum.map(fn {name, {msg, opts}} -> cerr(name, {msg, opts}) end)
          true -> %{name => "must be #{json_type(type)}"}
        end
      [{:validation, :embed}, {:type, type} | _] ->
        %{name => "must be #{json_type(type)}"}
    end
  end

  defp json_type({:array, type}), do: "array of #{json_type(type)}"
  defp json_type({:parameterized, Ecto.Enum, %{mappings: mappings}}), do: "one of [#{Keyword.values(mappings) |> Enum.join(", ")}]"
  defp json_type({:parameterized, Repo.Types.Integer, {min, max}}), do: "integer in range #{min}..#{max}"
  # defp json_type({:parameterized, Collection, %{items: type}}), do: "collection of #{json_type(type)}"
  defp json_type({:parameterized, type, %{args: [T: t]}}), do: "#{type} of #{json_type(t)}"
  defp json_type({:map, type}), do: "object of #{json_type(type)}"
  defp json_type(:map), do: "object"
  defp json_type(type) when is_atom(type) do
    cond do
      function_exported?(type, :values, 0) -> "one of [#{type.values() |> Enum.map(&to_string/1) |> Enum.join(", ")}]"
      # function_exported?(type, :type, 0) -> type.type()
      # "Elixir." <> type = "#{type}" ->
      #   type
      true ->
        type
    end
  end
  defp json_type(type), do: "#{inspect(type)}"
end

defmodule Util.Id do

  @spec to_json!(Ecto.UUID.t()) :: String.t()
  def to_json!(value), do: value
  @spec from_json!(String.t()) :: Ecto.UUID.t()
  def from_json!(value) when is_binary(value), do: Ecto.UUID.cast!(value)

  @spec to_string!(Ecto.UUID.t()) :: String.t()
  def to_string!(value), do: value
  @spec from_string!(String.t()) :: Ecto.UUID.t()
  def from_string!(value) when is_binary(value), do: Ecto.UUID.cast!(value)

end

defmodule Util.Retry do

  def retry_while(delays, fun, opts \\ []) when is_list(opts) do
    [0] |> Stream.concat(delays) |> Enum.reduce_while(nil, fn delay, _last_result ->
      :timer.sleep(delay)
      try do
        rc = cond do
          is_function(fun, 0) -> fun.()
          {m, f, a} = fun -> apply(m, f, a)
        end
        case rc do
          {:ok, result} -> {:halt, {:ok, result}}
          {:error, error} -> {:cont, {:error, error}}
          :ok -> {:halt, :ok}
          :error -> {:cont, :error}
        end
      rescue
        e ->
          if e.__struct__ in opts[:exceptions] do
            {:cont, {:error, {:exception, e.message}}}
          else
            reraise e, __STACKTRACE__
          end
      end
    end)
  end

  # def test() do
  #   retry_while([1000, 200, 300], fn ->
  #     d = NaiveDateTime.utc_now()
  #     IO.puts(d)
  #     {:error, d}
  #   end)
  # end

end

defmodule Util.Debug do

  def inspect(x, tag) do
    IO.inspect({tag, x})
    x
  end

  def dump(x, filename) do
    File.write!(filename, Kernel.inspect(x, [
      charlists: :as_lists,
      binaries: :as_strings,
      pretty: true,
      width: 64,
      limit: :infinity
    ]))
    x
  end

  def time_of(fun, args) do
    {time, _result} = :timer.tc(fun, args)
    IO.puts "Time: #{time / 1000000} s"
  end

end
