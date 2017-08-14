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

  def terminate(infos, type \\ :msg) do
    Logger.debug("Sending back #{inspect infos.answers}")
    send infos.pid, {:answer, infos, type}
  end

  def read_token(token) do
    token_name = List.last(String.split(token, "/"))
    case File.read(token) do
      {:ok, tok} -> Logger.debug("#{token_name} token successfully read")
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
    res = HTTPoison.get(url, [],
      [stream_to: self(), async: :once,
       hackney: [follow_redirect: true, max_redirect: 15]])
    case res do
      {:ok, resp} -> request(resp)
      {:error, %HTTPoison.Error{id: _, reason: reason}} -> %{code: reason, body: ""}
    end
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


# in memory mock
defmodule Hal.Tool.InMemory do

  def get(_url) do
    page = Enum.random([simple_one_line_title(),
                        multiline_title(),
                        greedy_title()]) # no_title()
    %{code: 200, body: page}
  end

  defp simple_one_line_title do
  """
  <!DOCTYPE html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <title>GitHub - w1gz/methal9k: Home of Meta Hal 9000 -- IRC bot &amp; more</title>
  </head>
  <body>
  something
  </body>
  </html>
  """
  end

  defp multiline_title do
  """
  <!DOCTYPE html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <title>GitHub - w1gz/methal9k: Home
  of Meta Hal 9000
  --
  IRC bot &amp; more</title>
  </head>
  <body>
  something
  </body>
  </html>
  """
  end

  defp greedy_title do
  """
  <!DOCTYPE html>
  <html lang="en">
  <head>
  <title>GitHub - w1gz/methal9k: Home of Meta Hal 9000 -- IRC bot &amp; more</title>
  <meta charset="utf-8">
  <title>GitHub - w1gz/methal9k: Home of Meta Hal 9000 -- IRC bot &amp; more</title>
  </head>
  <body>
  <title>GitHub - w1gz/methal9k: Home of Meta Hal 9000 -- IRC bot &amp; more</title>
  </body>
  </html>
  """
  end

  # defp no_title do
  # """
  # <!DOCTYPE html>
  # <html lang="en">
  # <head>
  # <meta charset="utf-8">
  # </head>
  # <body>
  # something
  # </body>
  # </html>
  # """
  # end

end
