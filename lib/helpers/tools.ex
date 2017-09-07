defmodule Hal.Tool do
  @moduledoc """
  Helpers/Tools for commonly used functions
  """

  require Logger

  def poolboy_conf(plugin, size \\ 10, overflow \\ 5) do
    [{:name, {:local, plugin}},
     {:worker_module, plugin},
     {:size, size}, {:max_overflow, overflow}]
  end

  def terminate(infos) do
    case infos.answers do
      [nil] -> nil
      _ ->
        Logger.debug("Sending back #{inspect infos.answers}")
        send infos.pid, {:answer, infos}
    end
  end

  def read_token(token) do
    token_name = List.last(String.split(token, "/"))
    case File.read(token) do
      {:ok, tok} -> Logger.info("#{token_name} token successfully read")
      String.trim(tok)
      _ -> Logger.warn("#{token_name} token not found")
        ""
    end
  end

  def quick_request(url) do
    with {:ok, res} <- HTTPoison.get(url, []),
         %HTTPoison.Response{body: body} <- res do
      Poison.decode!(body)
    end
  end

  # helper for the future cron that will clean ets/mnesia tables?
  def shift_time(time, unit \\ :days, timeshift \\ 7) do
    case unit do
      :days    -> Timex.shift(time, days: timeshift)
      :hours   -> Timex.shift(time, hours: timeshift)
      :minutes -> Timex.shift(time, minutes: timeshift)
      :seconds -> Timex.shift(time, seconds: timeshift)
    end
  end

  def get(url) do
    Logger.debug("GET on #{url}")
    HTTPoison.get(url, [],
      [stream_to: self(), async: :once,
       hackney: [follow_redirect: true, max_redirect: 15]])
  end

  def request(resp) do request(resp, _output = %{body: ""}) end
  def request(resp, output) do
    receive do
      %HTTPoison.AsyncStatus{code: code} ->
        Logger.debug("AsyncStatus #{inspect code}")
        put_and_next(output, :code, code, resp)
      %HTTPoison.AsyncHeaders{headers: headers} ->
        Logger.debug("AsyncHeaders #{inspect headers}")
        put_and_next(output, :headers, headers, resp)
      %HTTPoison.AsyncRedirect{to: to} ->
        Logger.debug("AsyncRedirect #{to}")
        {:ok, resp} = get(to)
        put_and_next(output, :to, to, resp)
      %HTTPoison.AsyncChunk{chunk: chunk} ->
        body = Map.get(output, :body) <> chunk
        output = Map.put(output, :body, body)
        case String.length(body) >= 100000 do # TODO find a better way
          true ->
            :hackney.stop_async(resp)
            output
          false ->
            {:ok, resp} = HTTPoison.stream_next(resp)
            request(resp, output)
        end
      %HTTPoison.AsyncEnd{} -> output
    end
  end

  defp put_and_next(map, key, value, resp) do
    output = Map.put_new(map, key, value)
    {:ok, resp} = HTTPoison.stream_next(resp)
    request(resp, output)
  end

end
