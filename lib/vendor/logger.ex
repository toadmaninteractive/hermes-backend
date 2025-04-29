defmodule Logger.Formatter.Vd do

  def format(level, message, {date, time}, metadata) do
    [
      Logger.Formatter.format_date(date),
      "T",
      Logger.Formatter.format_time(time),
      " [", Atom.to_string(level), "] ",
      case Keyword.get(metadata, :request_id) do
        s when is_binary(s) -> [s, " "]
        _ -> ""
      end,
      case Keyword.get(metadata, :domain) do
        tags when is_list(tags) -> [Enum.join(tags -- [:elixir], "/"), " "]
        _ -> ""
      end,
      message,
      " ",
      metadata
        # |> Keyword.put_new(:level, level)
        # |> Keyword.put_new(:message, message)
        |> Enum.map(fn {k, v} -> {k, meta_patch(v)} end)
        |> Keyword.delete(:request_id)
        |> Keyword.delete(:domain)
        |> inspect([
          charlists: :as_lists,
          binaries: :as_strings,
          pretty: true,
          width: 64,
          limit: :infinity
        ]),
      "\n",
    ]
  rescue
    e in ArgumentError ->
      "#{inspect(e)} ::: could not format: #{inspect({level, message, metadata})}"
  end

  defp meta_patch(%{stacktrace: stacktrace} = data) do
    stacktrace = stacktrace
      |> Enum.map(&meta_patch_stacktrace/1)
    %{data | stacktrace: stacktrace}
  end
  defp meta_patch(data), do: data

  defp meta_patch_stacktrace({m, f, a, info}) when is_list(a), do: meta_patch_stacktrace({m, f, length(a), info})
  defp meta_patch_stacktrace({m, f, a, info}) when is_integer(a) do
    case info[:file] do
      nil -> "&#{inspect(m)}.#{f}/#{a}"
      _ -> "&#{inspect(m)}.#{f}/#{a} @ #{info[:file]}:#{info[:line]}"
    end
  end

end
