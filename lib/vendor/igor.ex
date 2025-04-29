defmodule Igor do

  defmodule InternalError do
    defexception message: "Could not process the request due to server error. Please contact developers", plug_status: 500
  end

  # defmodule BadRequestError do
  #   defexception message: "Could not process the request due to client error", plug_status: 400
  # end

  # defmodule PayloadTooLargeError do
  #   defexception message: "The request is too large", plug_status: 413
  # end

  # defmodule UnsupportedMediaTypeError do
  #   defexception message: "Unsupported media type", plug_status: 415
  # end

  defmodule DecodeError do
    defexception error: "invalid_json", message: "Decode error", plug_status: 400
  end

  defmodule EncodeError do
    defexception message: "Encode error"
  end

  defmodule ParseError do
    defexception error: "invalid_data", message: "Parse error", details: nil, plug_status: 400

    def exception(errors) do
# IO.inspect({:PERR, errors})
      %__MODULE__{message: format_errors(errors) |> Enum.join("; "), details: errors}
    end

    # ----------------------------------------------------------------------------

    def format_errors(kw, prefix \\ nil)
    def format_errors(kw, prefix) when is_list(kw) do
      name = kw[:name]
      name = cond do
        name == nil -> "data"
        prefix == nil -> name
        is_integer(name) -> "#{prefix}[#{name}]"
        true -> "#{prefix}.#{name}"
      end
      message = cond do
        is_binary(kw[:message]) -> kw[:message]
        is_binary(kw[:range]) -> "must be in range #{kw[:range]}"
        is_list(kw[:values]) -> "must be one of [#{kw[:values] |> Enum.map(&to_string/1) |> Enum.join(", ")}]"
        # function_exported?(kw[:type], :values, 0) -> "must be one of [#{kw[:type].values() |> Enum.map(&to_string/1) |> Enum.join(", ")}]"
        true -> "must be #{json_type(kw[:type])}"
      end
      case kw[:errors] do
        nil -> ["#{name} #{message}"]
        errors -> errors |> Enum.map(fn e -> format_errors(e, name) end)
      end
        |> List.flatten()
    end

    defp json_type({:option, type}), do: json_type(type)
    defp json_type({:list, type}), do: "array of #{json_type(type)}"
    defp json_type({:list, ",", type}), do: "comma separated list of #{json_type(type)}"
    defp json_type({:list, separator, type}), do: "\"#{separator}\"-separated list of #{json_type(type)}"
    defp json_type({:map, key_type, value_type}), do: "map of <#{json_type(key_type)}, #{json_type(value_type)}>"
    defp json_type({:custom, type}), do: json_type(type)
    defp json_type({:custom, type, _type_args}), do: json_type(type)

    defp json_type(:sbyte), do: "integer in range [-128..127]"
    defp json_type(:byte), do: "integer in range [0..255]"
    defp json_type(:short), do: "integer in range [-32768..32767]"
    defp json_type(:ushort), do: "integer in range [0..65535]"
    defp json_type(:int), do: "integer in range [-2147483648..2147483647]"
    defp json_type(:uint), do: "integer in range [0..4294967295]"
    defp json_type(:long), do: "integer in range [-9223372036854775808..9223372036854775807]"
    defp json_type(:ulong), do: "integer in range [0..18446744073709551615]"

    defp json_type(type) when is_atom(type), do: "#{type}" |> String.replace("Elixir.", "")
    defp json_type(type), do: type

  end

  defmodule Util do

    def to_int(value, :sbyte) when is_integer(value) and value >= -128 and value <= 127, do: {:ok, value}
    def to_int(value, :byte) when is_integer(value) and value >= 0 and value <= 255, do: {:ok, value}
    def to_int(value, :short) when is_integer(value) and value >= -32768 and value <= 32767, do: {:ok, value}
    def to_int(value, :ushort) when is_integer(value) and value >= 0 and value <= 65535, do: {:ok, value}
    def to_int(value, :int) when is_integer(value) and value >= -2147483648 and value <= 2147483647, do: {:ok, value}
    def to_int(value, :uint) when is_integer(value) and value >= 0 and value <= 4294967295, do: {:ok, value}
    def to_int(value, :long) when is_integer(value) and value >= -9223372036854775808 and value <= 9223372036854775807, do: {:ok, value}
    def to_int(value, :ulong) when is_integer(value) and value >= 0 and value <= 18446744073709551615, do: {:ok, value}
    def to_int(value, type) when is_integer(value), do: {:error, type: type}
    def to_int(value, type) when is_binary(value) do
      case Integer.parse(value) do
        {value, ""} -> to_int(value, type)
        {_, _} -> {:error, type: type}
        :error -> {:error, type: type}
      end
    end
    def to_int(_, type), do: {:error, type: type}

    def to_float(value, :float) when is_number(value), do: {:ok, value / 1}
    def to_float(value, :double) when is_number(value), do: {:ok, value / 1}
    def to_float(value, type) when is_number(value), do: {:error, type: type}
    def to_float(value, type) when is_binary(value) and (type === :float or type === :double) do
      case Float.parse(value) do
        {value, ""} -> {:ok, value}
        {_, _} -> {:error, type: type}
        :error -> {:error, type: type}
      end
    end
    def to_float(_, type), do: {:error, type: type}

    def to_binary(value) when is_binary(value) do
      case Base.decode64(value) do
        {:ok, value} -> {:ok, value}
        :error -> {:error, type: :binary}
      end
    end
    def to_binary(_), do: {:error, type: :binary}

  end

  defmodule Json do

    @type type :: :boolean | :sbyte | :byte | :short | :ushort | :int | :uint | :long | :ulong | :float | :double | :binary | :string | :atom
      | {:custom, module()} | {:custom, module(), tuple()} | {:list, type()} | {:map, type(), type()} | {:option, type()}

    @type json :: term

    @spec encode!(json(), Keyword.t()) :: String.t()
    def encode!(value, opts \\ []), do: Jason.encode!(value, opts)

    # @spec decode(String.t()) :: {:ok, json()} | {:error, reason :: term()}
    # def decode(json) do
    #   case Jason.decode(json) do
    #     {:ok, value} -> {:ok, value}
    #     {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
    #   end
    # end

    @spec decode!(String.t(), Keyword.t()) :: json()
    def decode!(json, opts \\ []) do
      Jason.decode!(json, opts)
    rescue
      e in Jason.DecodeError ->
        reraise DecodeError, [message: "Junk at position #{e.position}"], __STACKTRACE__
    end

    # ----------------------------------------------------------------------------

    @spec parse_field!(json(), String.t(), type(), term()) :: term() | no_return()
    def parse_field!(json_object, key, type, default) do
      case parse_field(json_object, key, type, default) do
        {:ok, value} -> value
        {:error, reason} -> raise ParseError, reason
      end
    rescue
      e in MatchError ->
        {:error, reason} = e.term
        reraise ParseError, reason, __STACKTRACE__
    end

    @spec parse_field!(json(), String.t(), type()) :: term() | no_return()
    def parse_field!(json_object, key, type) do
      case parse_field(json_object, key, type) do
        {:ok, value} -> value
        {:error, reason} -> raise ParseError, reason
      end
    rescue
      e in MatchError ->
        {:error, reason} = e.term
        reraise ParseError, reason, __STACKTRACE__
    end

    @spec parse_field(json(), String.t(), type(), term()) :: {:ok, term()} | {:error, term()}
    def parse_field(json_object, key, type, default) when is_map(json_object) or is_struct(json_object) do
      case Map.get(json_object, key) do
        nil when elem(type, 0) === :option -> {:ok, nil}
        nil -> {:ok, default}
        value -> case parse_value(value, type) do
          {:ok, value} -> {:ok, value}
          {:error, reason} -> {:error, [{:name, key} | reason]}
        end
      end
    end
    # def parse_field(_, _key, _, _), do: {:error, type: :map}
    def parse_field(_, key, type, _), do: {:error, name: key, type: type}

    @spec parse_field(json(), String.t(), type()) :: {:ok, term()} | {:error, term()}
    def parse_field(json_object, key, type) when is_map(json_object) or is_struct(json_object) do
      case Map.get(json_object, key) do
        nil when elem(type, 0) === :option -> {:ok, nil}
        nil -> {:error, name: key, type: type}
        value -> case parse_value(value, type) do
          {:ok, value} -> {:ok, value}
          {:error, reason} -> {:error, [{:name, key} | reason]}
        end
      end
    end
    # def parse_field(_, _key, _), do: {:error, type: :map}
    def parse_field(_, key, type), do: {:error, name: key, type: type}

    @doc false
    def field_from_json(map, json, json_key, type, map_key) do
      # TODO: still check field semantic validity!
      case Map.fetch(json, json_key) do
        {:ok, value} -> Map.put(map, map_key, parse_value(value, type))
        :error -> map
      end
    end

    @doc false
    def field_to_json(json, map, map_key, type, json_key) do
      case Map.fetch(map, map_key) do
        {:ok, value} -> Map.put(json, json_key, Json.pack_value(value, type))
        :error -> json
      end
    end

    # ----------------------------------------------------------------------------

    @spec pack_field(json(), String.t(), term(), type()) :: json()
    def pack_field(json_object, _key, nil, _type), do: json_object
    def pack_field(json_object, key, value, type), do: Map.put(json_object, key, pack_value(value, type))

    # ----------------------------------------------------------------------------

    @spec parse_value!(json(), type()) :: term() | no_return()
    def parse_value!(value, type) do
      rc = parse_value(value, type)
      case rc do
      # case parse_value(value, type) do
        {:ok, value} -> value
        {:error, reason} -> raise ParseError, reason
      end
    rescue
      e in MatchError ->
        {:error, reason} = e.term
        reraise ParseError, reason, __STACKTRACE__
    end

    @spec parse_value(json(), type()) :: {:ok, term()} | {:error, term()}

    def parse_value(value, :string) when is_binary(value), do: {:ok, value}
    def parse_value(value, :string) when is_atom(value), do: {:ok, Atom.to_string(value)}
    def parse_value(_, :string), do: {:error, type: :string}

    def parse_value(value, :atom) when is_atom(value), do: {:ok, value}
    def parse_value(value, :atom) when is_binary(value), do: {:ok, String.to_atom(value)}
    def parse_value(_, :atom), do: {:error, type: :atom}

    def parse_value(value, type)
      when type === :sbyte or type === :byte or type === :short or type === :ushort
      or type === :int or type === :uint or type === :long or type === :ulong
    do
      Util.to_int(value, type)
    end

    def parse_value(value, :boolean) when is_boolean(value), do: {:ok, value}
    def parse_value("true", :boolean), do: {:ok, true}
    def parse_value("false", :boolean), do: {:ok, false}
    def parse_value(1, :boolean), do: {:ok, true}
    def parse_value(0, :boolean), do: {:ok, false}
    def parse_value("1", :boolean), do: {:ok, true}
    def parse_value("0", :boolean), do: {:ok, false}
    def parse_value(_, :boolean), do: {:error, type: :boolean}

    def parse_value(value, type) when type === :float or type === :double, do: Util.to_float(value, type)

    def parse_value(value, :binary), do: Util.to_binary(value)

    def parse_value(value, :json), do: {:ok, value}

    def parse_value(value, {:list, item_type}) when is_list(value) do
      value
        |> Enum.with_index(fn v, i ->
          case parse_value(v, item_type) do
            {:ok, item} -> {:ok, item}
            {:error, reason} -> {:error, [{:name, i} | reason]}
          end
        end)
        |> Enum.group_by(& elem(&1, 0), & elem(&1, 1))
        |> case do
          # %{ok: kv, error: _errors} -> {:ok, kv}
          %{error: errors} -> {:error, type: {:list, item_type}, errors: errors}
          %{ok: kv} -> {:ok, kv}
          %{} -> {:ok, []}
        end
    end
    def parse_value(_, {:list, item_type}), do: {:error, type: {:list, item_type}}

    def parse_value(value, {:list, separator, item_type}) when is_binary(value) and is_binary(separator) do
      value
        |> String.split(separator, global: true)
        |> parse_value({:list, item_type})
    end
    def parse_value(_, {:list, separator, item_type}), do: {:error, type: {:list, separator, item_type}}

    def parse_value(value, {:map, key_type, value_type}) when is_map(value) or is_struct(value) do
      value
        |> Enum.map(fn {key, value} ->
          # TODO: honor key error here
          {:ok, parsed_key} = parse_key(key, key_type)
          case parse_value(value, value_type) do
            {:ok, item} -> {:ok, {parsed_key, item}}
            {:error, reason} -> {:error, [{:name, parsed_key} | reason]}
          end
        end)
        |> Enum.group_by(& elem(&1, 0), & elem(&1, 1))
        |> case do
          %{error: errors} -> {:error, type: {:map, key_type, value_type}, errors: errors}
          %{ok: kv} -> {:ok, kv |> Enum.into(%{})}
          %{} -> {:ok, %{}}
        end
    end
    def parse_value(_, {:map, key_type, value_type}), do: {:error, type: {:map, key_type, value_type}}

    def parse_value(nil, {:option, _}), do: {:ok, nil}
    # NB: let custom module decide on nil
    def parse_value(nil, type), do: {:error, type: type}
    def parse_value(value, {:option, type}), do: parse_value(value, type)

    def parse_value(value, {:custom, module}) do
      {:ok, module.from_json!(value)}
    rescue
      e in FunctionClauseError ->
        if e.function === :from_json! do
          values = if function_exported?(module, :values, 0), do: module.values(), else: nil
          {:error, type: {:custom, module}, values: values}
        else
          reraise e, __STACKTRACE__
        end
      e in ParseError -> {:error, type: {:custom, module}, errors: [e.details]}
    end
    def parse_value(value, {:custom, module, type_args}) do
      {:ok, module.from_json!(value, type_args)}
    rescue
      e in FunctionClauseError ->
        if e.function === :from_json! do
          values = if function_exported?(module, :values, 0), do: module.values(), else: nil
          {:error, type: {:custom, module}, values: values}
        else
          reraise e, __STACKTRACE__
        end
      e in ParseError -> {:error, type: {:custom, module}, errors: [e.details]}
    end

    # ----------------------------------------------------------------------------

    defp parse_key(key, type), do: parse_value(key, type)

    # ----------------------------------------------------------------------------

    @spec pack_value(term(), type()) :: json()
    def pack_value(value, :string) when is_binary(value), do: value
    def pack_value(value, :string) when is_atom(value), do: Atom.to_string(value)
    # def pack_value(value, :atom) when is_binary(value), do: String.to_atom(value) # TODO: FIXME: existing atom?
    # def pack_value(value, :atom) when is_atom(value), do: value
    def pack_value(value, :atom) when is_binary(value), do: value
    def pack_value(value, :atom) when is_atom(value), do: Atom.to_string(value)

    def pack_value(value, :sbyte) when is_integer(value), do: value |> check_min_max(-128, 127)
    def pack_value(value, :byte) when is_integer(value), do: value |> check_min_max(0, 255)
    def pack_value(value, :short) when is_integer(value), do: value |> check_min_max(-32768, 32767)
    def pack_value(value, :ushort) when is_integer(value), do: value |> check_min_max(0, 65535)
    def pack_value(value, :int) when is_integer(value), do: value |> check_min_max(-2147483648, 2147483647)
    def pack_value(value, :uint) when is_integer(value), do: value |> check_min_max(0, 4294967295)
    def pack_value(value, :long) when is_integer(value), do: value |> check_min_max(-9223372036854775808, 9223372036854775807)
    def pack_value(value, :ulong) when is_integer(value), do: value |> check_min_max(0, 18446744073709551615)

    def pack_value(value, :boolean) when is_boolean(value), do: value

    def pack_value(value, :float) when is_number(value), do: value
    def pack_value(value, :double) when is_number(value), do: value

    def pack_value(value, :binary) when is_binary(value), do: Base.encode64(value)

    def pack_value(value, :json), do: value
    def pack_value(list, {:list, type}) when is_list(list), do: (for value <- list, do: pack_value(value, type))
    def pack_value(dict, {:map, key_type, value_type}) when is_map(dict), do: (for {key, value} <- dict, into: %{}, do: {pack_key(key, key_type), pack_value(value, value_type)})
    def pack_value(nil, {:option, _}), do: nil
    def pack_value(value, {:option, type}), do: pack_value(value, type)
    def pack_value(value, {:custom, module}), do: module.to_json!(value)
    def pack_value(value, {:custom, module, type_args}), do: module.to_json!(value, type_args)

    def pack_value(value, type), do: raise "Can not pack #{inspect value} to #{inspect type}"

    # ----------------------------------------------------------------------------

    defp pack_key(true, :boolean), do: "true"
    defp pack_key(false, :boolean), do: "false"
    defp pack_key(value, :sbyte) when is_integer(value) and value >= -128 and value <= 127, do: Integer.to_string(value)
    defp pack_key(value, :byte) when is_integer(value) and value >= 0 and value <= 255, do: Integer.to_string(value)
    defp pack_key(value, :short) when is_integer(value) and value >= -32768 and value <= 32767, do: Integer.to_string(value)
    defp pack_key(value, :ushort) when is_integer(value) and value >= 0 and value <= 65535, do: Integer.to_string(value)
    defp pack_key(value, :int) when is_integer(value) and value >= -2147483648 and value <= 2147483647, do: Integer.to_string(value)
    defp pack_key(value, :uint) when is_integer(value) and value >= 0 and value <= 4294967295, do: Integer.to_string(value)
    defp pack_key(value, :long) when is_integer(value) and value >= -9223372036854775808 and value <= 9223372036854775807, do: Integer.to_string(value)
    defp pack_key(value, :ulong) when is_integer(value) and value >= 0 and value <= 18446744073709551615, do: Integer.to_string(value)
    defp pack_key(value, :float) when is_number(value), do: Float.to_string(value / 1)
    defp pack_key(value, :double) when is_number(value), do: Float.to_string(value / 1)
    defp pack_key(value, :binary) when is_binary(value), do: value
    defp pack_key(value, :string) when is_binary(value), do: value
    defp pack_key(value, :atom) when is_atom(value), do: Atom.to_string(value)
    defp pack_key(value, {:custom, module}), do: module.to_json!(value)
    defp pack_key(value, {:custom, module, type_args}), do: module.to_json!(value, type_args)
    # defp pack_key(_, _), do: raise EncodeError, "Invalid key"

    # ----------------------------------------------------------------------------

    # TODO: remove
    defp check_min_max(value, min, max)
      when is_integer(value) and is_integer(min) and is_integer(max)
      and value >= min and value <= max
    do
      value
    end
    defp check_min_max(value, min, max)
      when is_integer(value) and is_integer(min) and is_integer(max)
    do
      raise DecodeError, message: "Invalid value range", info: "[#{min}..#{max}]"
    end

  end

  defmodule Strings do

    # ----------------------------------------------------------------------------

    # @spec parse!(String.t(), type()) :: term() | no_return()
    def parse!(value, type) do
      rc = parse(value, type)
      case rc do
      # case parse(value, type) do
        {:ok, value} -> value
        {:error, reason} -> raise ParseError, reason
      end
    rescue
      e in MatchError ->
        {:error, reason} = e.term
        reraise ParseError, reason, __STACKTRACE__
    end

    # ----------------------------------------------------------------------------

    def parse(value, {:option, type}), do: parse(value, type, nil)
    def parse(nil, type), do: {:error, type: type}
    def parse(value, type) when is_binary(value), do: parse_string(value, type)
    def parse(_, type), do: {:error, type: type}

    def parse(nil, _type, default), do: {:ok, default}
    def parse(value, type, _default), do: parse_string(value, type)

    # ----------------------------------------------------------------------------

    def format(value, {:option, type}), do: format_value(value, type)
    def format(value, type), do: format_value(value, type)

    # ----------------------------------------------------------------------------

    defp parse_string(string, :string) when is_binary(string), do: {:ok, string}
    defp parse_string(string, :atom), do: {:ok, String.to_atom(string)}

    defp parse_string(string, type)
      when type === :sbyte or type === :byte or type === :short or type === :ushort
      or type === :int or type === :uint or type === :long or type === :ulong
    do
      Util.to_int(string, type)
    end

    defp parse_string(string, :boolean), do: Json.parse_value(string, :boolean)

    defp parse_string(string, type) when type === :float or type === :double, do: Util.to_float(string, type)

    defp parse_string(string, :binary), do: Util.to_binary(string)

    defp parse_string(string, {:list, separator, item_type}) when is_binary(string) do
      string
        |> String.split(separator, global: true)
        |> Json.parse_value({:list, item_type})
    end
    # TODO: {:map, ...}

    defp parse_string(string, {:custom, module}) do
      {:ok, module.from_string!(string)}
    rescue
      _e -> {:error, type: {:custom, module}}
    end
    defp parse_string(string, {:custom, module, type_args}) do
      {:ok, module.from_string!(string, type_args)}
    rescue
      _e -> {:error, type: {:custom, module, type_args}}
    end

    defp parse_string(_, type), do: {:error, type: type}

    # ----------------------------------------------------------------------------

    defp format_value(value, :string) when is_binary(value), do: value
    defp format_value(value, :atom) when is_atom(value), do: Atom.to_string(value)

    defp format_value(value, type)
      when type === :sbyte or type === :byte or type === :short or type === :ushort
      or type === :int or type === :uint or type === :long or type === :ulong
    do
      Integer.to_string(value)
    end

    defp format_value(true, :boolean), do: "true"
    defp format_value(false, :boolean), do: "false"

    defp format_value(value, type) when type === :float or type === :double, do: Float.to_string(value)

    defp format_value(value, :binary) when is_binary(value), do: Base.encode64(value)

    defp format_value(value, {:list, separator, item_type}) when is_list(value) do
      value
        |> Enum.map(& format_value(&1, item_type))
        |> Enum.join(separator)
    end

    # ----------------------------------------------------------------------------

  end

  defmodule Http do

    defmodule HttpError do

      defexception [:status_code, :body, :headers]

      def message(exception), do: "HTTP error #{exception.status_code}"

    end

    def parse_path(key, json_object, type), do: Json.parse_field(json_object, key, type)
    def parse_path(key, json_object, type, default), do: Json.parse_field(json_object, key, type, default)

    def parse_query(key, json_object, type), do: Json.parse_field(json_object, key, type)
    def parse_query(key, json_object, type, default), do: Json.parse_field(json_object, key, type, default)

    def parse_header(key, json_object, type), do: Json.parse_field(json_object, key, type)
    def parse_header(key, json_object, type, default), do: Json.parse_field(json_object, key, type, default)

    def compose_query(query_parts) do
      query_parts
        |> Enum.flat_map(&format_query/1)
        |> compose_query_string()
    end

    defp compose_query_string(parts) do
      for {name, value} <- parts do [name, "=", value] end |> Enum.join("&")
    end

    defp format_query({name, value}), do: [{name, value}]
    defp format_query({name, value, type}), do: format_query(name, value, type)
    defp format_query({_name, value, _format, default}) when value === default, do: []
    defp format_query({name, value, type, _default}), do: format_query(name, value, type)

    defp format_query(_name, nil, _type), do: []
    defp format_query(name, value, {:option, type}), do: format_query(name, value, type)
    defp format_query(name, value, {:list, item_type}) when is_list(value), do: (for item <- value, do: {name, format_value(item, item_type)})
    defp format_query(name, value, type), do: [ {name, format_value(value, type)} ]

    # def parse_query(param, qs, {:option, type}) do
    #   parse_query(param, qs, type, nil)
    # end
    # def parse_query(param, qs, type) do
    #   try do
    #     case parse_query_opt(param, qs, type) do
    #       nil -> raise BadRequestError, message: "Missing query parameter #{param}"
    #       value -> value
    #     end
    #   rescue
    #     bad_request in BadRequestError -> reraise bad_request, __STACKTRACE__
    #     _ -> raise BadRequestError, message: "Malformed query parameter #{param}"
    #   end
    # end

    # def parse_query(param, qs, type, default) do
    #   try do
    #     case parse_query_opt(param, qs, type) do
    #       nil -> default
    #       value -> value
    #     end
    #   rescue
    #     _ -> raise BadRequestError, message: "Malformed query parameter #{param}"
    #   end
    # end

    # defp parse_query_opt(param, qs, {:custom_query, fun}) do
    #   fun.(param, qs)
    # end
    # defp parse_query_opt(param, qs, {:option, type}) do
    #   parse_query_opt(param, qs, type)
    # end
    # defp parse_query_opt(param, qs, type) do
    #   case Map.get(qs, param) do
    #     nil -> nil
    #     string -> parse_value(string, type)
    #   end
    # end

    # def parse_header(header, values, {:option, type}) do
    #   parse_header(header, values, type, nil)
    # end
    # def parse_header(header, [], _Type) do
    #   raise BadRequestError, message: "Missing header #{header}"
    # end
    # def parse_header(_header, [value| _], type) when is_binary(value) do
    #   parse_value(value, type)
    # end

    # def parse_header(_header, [], _type, default), do: default
    # def parse_header(header, values, type, _default), do: parse_header(header, values, type)

    # def parse_path(param, path_params, type) do
    #   case Map.get(path_params, param) do
    #     nil -> raise BadRequestError, message: "Missing path param #{param}"
    #     value ->
    #       try do
    #         parse_value(value, type)
    #       rescue
    #         _ -> raise BadRequestError, message: "Invalid path param #{param}"
    #       end
    #   end
    # end

    # def parse_value("true", :boolean), do: true
    # def parse_value("false", :boolean), do: false
    # def parse_value(string, :sbyte), do: String.to_integer(string)
    # def parse_value(string, :byte), do: String.to_integer(string)
    # def parse_value(string, :short), do: String.to_integer(string)
    # def parse_value(string, :ushort), do: String.to_integer(string)
    # def parse_value(string, :int), do: String.to_integer(string)
    # def parse_value(string, :uint), do: String.to_integer(string)
    # def parse_value(string, :long), do: String.to_integer(string)
    # def parse_value(string, :ulong), do: String.to_integer(string)
    # def parse_value(string, :float), do: Util.to_float(string, :float)
    # def parse_value(string, :double), do: Util.to_float(string, :double)
    # def parse_value(string, :string), do: string
    # def parse_value(string, :binary), do: string
    # def parse_value(string, :atom), do: String.to_atom(string)
    # def parse_value(value, {:list, separator, item_type}), do: for item <- String.split(value, separator, global: true), do: parse_value(item, item_type)
    # def parse_value(value, {:custom, module}), do: module.from_string!(value)
    # def parse_value(value, {:json, json_tag}), do: value |> Json.decode! |> Json.parse_value(json_tag)

    def format_value(true, :boolean), do: "true"
    def format_value(false, :boolean), do: "false"
    def format_value(value, :sbyte) when is_integer(value), do: Integer.to_string(value)
    def format_value(value, :byte) when is_integer(value), do: Integer.to_string(value)
    def format_value(value, :short) when is_integer(value), do: Integer.to_string(value)
    def format_value(value, :ushort) when is_integer(value), do: Integer.to_string(value)
    def format_value(value, :int) when is_integer(value), do: Integer.to_string(value)
    def format_value(value, :uint) when is_integer(value), do: Integer.to_string(value)
    def format_value(value, :long) when is_integer(value), do: Integer.to_string(value)
    def format_value(value, :ulong) when is_integer(value), do: Integer.to_string(value)
    def format_value(value, :float) when is_number(value), do: Float.to_string(value)
    def format_value(value, :double) when is_number(value), do: Float.to_string(value)
    def format_value(value, :binary) when is_binary(value), do: URI.encode(value)
    def format_value(value, :string) when is_binary(value), do: URI.encode(value)
    def format_value(value, :atom) when is_atom(value), do: URI.encode(Atom.to_string(value))
    def format_value(value, {:list, separator, item_type}) when is_list(value), do: Enum.join(for item <- value do format_value(item, item_type) end, separator)
    def format_value(value, {:custom, module}), do: module.to_string!(value)
    def format_value(value, {:json, json_tag}), do: value |> Json.pack_value(json_tag) |> Json.encode! |> URI.encode

  end

  defprotocol Exception do
    @fallback_to_any true
    def prepare(e)
    def wrap(e)
    def handle(e, stacktrace, conn, method)
  end

  defimpl Exception, for: Any do
    def prepare(e) when is_struct(e, ParseError), do: Map.put(e, :details, nil)
    def prepare(e), do: e
    def wrap(e) when is_struct(e, ParseError), do: wrap(Map.drop(Map.from_struct(e), [:details]))
    # def wrap(e) when is_struct(e, ParseError) do
    #   errors = e.details
    #   e = Map.drop(Map.from_struct(e), [:details])
    #   e = Map.put(e, :message, ParseError.format_errors(errors) |> Enum.join("; "))
    #   wrap(e)
    # end
    def wrap(e) when is_struct(e), do: wrap(Map.from_struct(e))
    def wrap(e) when is_map(e) do
      # e
      require Logger
      e
        |> Map.merge(%{log_id: Logger.metadata[:request_id]})
        |> Map.drop([:__exception__, :plug_status])
        # |> Enum.reject(& elem(&1, 1) == nil)
        |> Enum.into(%{})
    end
    def handle(e, stacktrace, conn, method) do
      require Logger
# IO.inspect({:exc, e})
      status_code = Plug.Exception.status(e)
      e = prepare(e)
      e = cond do
        status_code == 500 ->
          # Logger.emergency("rpc_exc: #{Elixir.Exception.format(:error, e, [])}", data: %{method: method, exception: e, stacktrace: stacktrace}, domain: [:rpc])
          Logger.emergency("rpc_exc: #{method}: #{Elixir.Exception.format(:error, e, [])}", data: %{exception: e, stacktrace: stacktrace}, domain: [:rpc])
          %InternalError{}
        # is_map_key(e, :message) and is_binary(e.message) ->
        #   Logger.warn("rpc_err: #{e.message}", data: %{method: method, exception: e}, domain: [:rpc])
        #   e
        # true ->
        #   Logger.warn("rpc_err", data: %{method: method, exception: e}, domain: [:rpc])
        #   e
        true ->
          # Logger.warn("rpc_err: #{Elixir.Exception.format(:error, e, [])}", data: %{method: method, exception: e}, domain: [:rpc])
          Logger.warn("rpc_err: #{method}: #{Elixir.Exception.format(:error, e, [])}", data: %{exception: e}, domain: [:rpc])
          e
      end
      e = wrap(e)
      body = try do
        Json.encode!(e)
      rescue
        _ -> Json.encode!(%{error: inspect(e)})
      end
      conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status_code, body)
    end
  end

#   defimpl Exception, for: Any do
#     def wrap(e) when is_struct(e), do: wrap(Map.from_struct(e))
#     def wrap(e) when is_map(e) do
# # IO.inspect({:wr, e})
#       require Logger
#       e
#         |> Map.merge(%{log_id: Logger.metadata[:request_id]})
#         |> Map.drop([:__exception__])
#         |> Enum.reject(& elem(&1, 1) == nil)
#         |> Enum.into(%{})
#     end
#     def handle(e, stacktrace, conn, method) when is_struct(e, ParseError) do
#       handle(%DataProtocol.BadRequestError{error: "Invalid data", message: e.message}, stacktrace, conn, method)
#     end
#     def handle(e, stacktrace, conn, method) do
# # IO.inspect({:he, e})
# # IO.inspect({:he, __ENV__})
#       require Logger
#       status_code = Plug.Exception.status(e)
#       e = cond do
#         status_code == 500 ->
#           Logger.emergency("rpc_exc: #{Elixir.Exception.format(:error, e, [])}", data: %{method: method, exception: e, stacktrace: stacktrace}, domain: [:rpc])
#           %DataProtocol.InternalServerError{}
#         is_map_key(e, :message) and is_binary(e.message) ->
#           Logger.warn("rpc_err: #{e.message}", data: %{method: method, exception: e}, domain: [:rpc])
#           e
#         true ->
#           %{error: inspect(e)}
#       end
#       body = wrap(e)
#         |> Json.encode!()
#       conn
#         |> Plug.Conn.put_resp_content_type("application/json")
#         |> Plug.Conn.send_resp(status_code, body)
#     end
#   end

end
