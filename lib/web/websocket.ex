defmodule Web.WebSocket do
  @moduledoc """
  WebSocket handler
  """

  @behaviour :cowboy_websocket

  require Logger

  def init(req, _opts) do
    api_key = Util.config(:hermes, [:web, :api_key])
    case :cowboy_req.header("x-api-key", req) do
      ^api_key ->
        {:cowboy_websocket, req, %{}}
      _ ->
        {:cowboy_websocket, req, %{}}
      # _ ->
      #   # NB: both missing and non-matching api key means non-authenticated
      #   {:ok, :cowboy_req.reply(401, %{
      #       <<"www-authenticate">> => <<"x-api-key header">>
      #   }, req), opts}
    end
  end

  def websocket_init(state) do
    Process.send_after(self(), :heartbeat, Util.config(:hermes, [:web, :websocket, :heartbeat]))
    {:ok, state, :hibernate}
  end

  def websocket_handle({:text, json}, state) do
    case Jason.decode(json) do
      {:ok, payload} ->
        case process_json(payload, state) do
          :ok ->
            :ok
          {:error, reason} ->
            send self(), {:send, :text, reason}
        end
      {:error, _reason} ->
        send self(), {:send, :text, invalid_data(:json, %{})}
    end
    {:ok, state, :hibernate}
  end
  def websocket_handle(_frame, state) do
    {:ok, state, :hibernate}
  end

  def websocket_info({:send, :text, msg}, state) do
    Logger.debug([reply: msg], [caption: :ws])
    {[{:text, Jason.encode!(msg)}], state, :hibernate}
  end
  def websocket_info({:send, :binary, msg}, state) do
    {[{:binary, msg}], state, :hibernate}
  end
  def websocket_info(:heartbeat, state) do
    Process.send_after(self(), :heartbeat, Util.config(:hermes, [:web, :websocket, :heartbeat]))
    {[:ping], state, :hibernate}
  end
  def websocket_info(:disconnect, state) do
    {:stop, state, :hibernate}
  end
  def websocket_info(_info, state) do
    {:ok, state, :hibernate}
  end

  # internal functions

  defp process_json(_req, _state) do
  end

  defp invalid_data(reason, base) do
    Map.merge(base, %{
      error: %{
        code: 2,
        message: "InvalidData",
        data: %{
          reason: reason
        }
      }
    })
  end

end
