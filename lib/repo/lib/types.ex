defmodule Repo.Types do

  defmodule Stringy do
    use Ecto.Type
    def type, do: :string
    def cast(nil), do: {:ok, nil}
    def cast(value), do: {:ok, to_string(value)}
    def load(string) when is_bitstring(string), do: {:ok, string}
    def dump(string) when is_bitstring(string), do: {:ok, string}
    def dump(_), do: :error
  end

  defmodule StringyTrimmed do
    use Ecto.Type
    def type, do: :string
    def cast(nil), do: {:ok, nil}
    def cast(value), do: {:ok, Util.trimmed(to_string(value))}
    def load(string) when is_bitstring(string), do: {:ok, string}
    def dump(string) when is_bitstring(string), do: {:ok, Util.trimmed(string)}
    def dump(_), do: :error
  end

  defmodule StringyTrimmedLower do
    use Ecto.Type
    def type, do: :string
    def cast(nil), do: {:ok, nil}
    def cast(value), do: {:ok, Util.trimmed_lower(to_string(value))}
    def load(string) when is_bitstring(string), do: {:ok, string}
    def dump(string) when is_bitstring(string), do: {:ok, Util.trimmed_lower(string)}
    def dump(_), do: :error
  end
end
