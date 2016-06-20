defmodule Core.PluginWeather do
  use GenServer

  defmodule Credentials do
    defstruct appid: nil
  end

  # Client API
  def start_link(args, opts \\ []) do
    IO.puts("[INFO] New PluginWeather")
    GenServer.start_link(__MODULE__, args, opts)
  end

  def current_weather(pid, params, req) do
    GenServer.cast(pid, {:current_weather, params, req})
  end

  def hourly(pid, params, req) do
    GenServer.cast(pid, {:forecast_hourly, params, req})
  end

  def daily(pid, params, req) do
    GenServer.cast(pid, {:forecast_daily, params, req})
  end

  # Server callbacks
  def init(_state) do
    # TODO reduce/simplify the path to the weather token
    {:ok, appid} = File.read("apps/core/lib/plugins/weather/weather_token.sec")
    IO.puts("[INFO] token api was successfully read")

    # construct our initial state
    appid = String.strip(appid)
    new_state = %Credentials{appid: appid}
    {:ok, new_state}
  end

  def handle_cast(args={:current_weather, _params, _req}, state) do
    url = "api.openweathermap.org/data/2.5/weather"
    get_weather(args, state.appid, url)
    {:noreply, state}
  end

  def handle_cast(args={:forecast_hourly, _params, _req}, state) do
    url = "api.openweathermap.org/data/2.5/forecast"
    get_weather(args, state.appid, url)
    {:noreply, state}
  end

  def handle_cast(args={:forecast_daily, _params, _req}, state) do
    url = "api.openweathermap.org/data/2.5/forecast/daily"
    get_weather(args, state.appid, url)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end


  # Internal functions
  defp get_weather(_args={type, params, req={uid, frompid, _msg}}, appid, url) do
    output = send_request(params, uid, frompid, appid, url)
    answer = format_for_human(output, req, type)
    answers = case is_list(answer) do
                true  -> answer
                false -> [answer]
              end
    send frompid, {:answer, {uid, answers}}
  end

  defp send_request(params, uid, frompid, appid, url) do
    # construct the city name from the parameters
    city = cond do
      params != [] -> Enum.join(params, " ")
      true ->
        answer = "Please give me a location to work with."
        send frompid, {:answer, {uid, [answer]}}
        throw("No arguments for weather, crashing")
    end

    # request some weather informations
    query_params = %{q: city, APPID: appid}
    {:ok, res} = HTTPoison.get(url, [], stream_to: self, params: query_params)
    {:ok, output} = parse_async(res.id)

    # does the request succeed?
    code = output[:code]
    case code do
      200 -> output
      _   ->
        answer = "¡Bonk! Request failed with HTTP.code == #{code}"
        send frompid, {:answer, {uid, [answer]}}
        throw(answer)
    end
  end

  defp parse_async(id) do parse_async(id, _output = %{:code => "", :data => ""}) end

  defp parse_async(id, output) do
    receive do
      %HTTPoison.AsyncEnd{id: ^id}                     -> {:ok, output}
      %HTTPoison.AsyncStatus{id: ^id, code: code}      -> parse_async(id, Map.put(output, :code, code))
      %HTTPoison.AsyncHeaders{id: ^id}                 -> parse_async(id, output)
      %HTTPoison.AsyncChunk{id: ^id, chunk: new_chunk} ->
        previous_data = Map.get(output, :data)
        res_data = Map.put(output, :data, previous_data <> new_chunk)
        parse_async(id, res_data)
    end
  end

  defp format_for_human(output, _req={uid, frompid, _msg}, weather_type) do
    json = output[:data]
    raw = Poison.decode!(json)

    # The API will either return a integer or a string
    code = raw["cod"]
    code = case is_integer(code) do
             true -> code
             false -> String.to_integer(code)
           end

    # check if the API request was successful
    if code != 200 do
      error_msg = raw["message"]
      answer = "The API returns #{code}, #{error_msg}"
      send frompid, {:answer, {uid, [answer]}}
      throw(answer)
    end

    case weather_type do
      :current_weather -> format_current_weather(raw)
      :forecast_hourly -> format_forecast_hourly(raw)
      :forecast_daily  -> format_forecast_daily(raw)
    end
  end

  defp format_forecast_hourly(raw) do
    answers =
      Enum.filter(raw["list"], fn(fday) ->
        {:ok, hnow} = Timex.format(Timex.DateTime.now, "%H", :strftime)
        {_, {hour,_min,_sec}} = :calendar.gregorian_seconds_to_datetime(fday["dt"])
        hnow >= hour
      end)
      |> Enum.map(fn(fday) ->
      # general conditions
      datetime = fday["dt_txt"]
      temp = Float.round(fday["main"]["temp"] - 273.15, 1)
      pressure = round(fday["main"]["pressure"])
      desc = hd(fday["weather"])["description"]

      # construct the answer
      weather_for_human = [
        "#{datetime} UTC",
        "#{pressure} hPa, #{temp}°C",
        "#{desc}"
      ]
      Enum.join(weather_for_human, " ~ ")
    end)
    |> Enum.take(4)

      # add the header
      name = raw["city"]["name"]
      country = raw["city"]["country"]
      List.insert_at(answers, 0, "#{name}, #{country}.")
  end

  defp format_forecast_daily(raw) do
    answers =
      Enum.take(raw["list"], 4)
      |> Enum.map(fn(fday) ->
      time = fday["dt"]
      {{year,month,day}, {_hour,_min,_sec}} = :calendar.gregorian_seconds_to_datetime(time)
      year = year + 1970

      # temps of the day
      tmorn = Float.round(fday["temp"]["morn"] - 273.15, 1)
      teve = Float.round(fday["temp"]["eve"] - 273.15, 1)
      tnight = Float.round(fday["temp"]["night"] - 273.15, 1)

      # general conditions
      pressure = round(fday["pressure"])
      desc = hd(fday["weather"])["description"]

      # construct the answer
      weather_for_human = [
        "#{year}-#{month}-#{day}",
        "#{pressure} hPa",
        "M:#{tmorn}C  E:#{teve}C  N:#{tnight}C",
        "#{desc}"
      ]
      Enum.join(weather_for_human, " ~ ")
    end)

      # add the header
      name = raw["city"]["name"]
      country = raw["city"]["country"]
      List.insert_at(answers, 0, "#{name}, #{country}. Temps are for Morning, Evening and Night")
  end

  defp format_current_weather(raw) do
    # 'basic' weather & name
    name = raw["name"]
    desc = hd(raw["weather"])["description"]

    # 'sys' complementary infos
    country = raw["sys"]["country"]
    sunrise = raw["sys"]["sunrise"]
    sunset  = raw["sys"]["sunset"]
    # convert to a more readable format
    {_date, {rhour,rmin,_sec}} = :calendar.gregorian_seconds_to_datetime(sunrise)
    {_date, {shour,smin,_sec}} = :calendar.gregorian_seconds_to_datetime(sunset)
    sunrise = "#{rhour}h#{rmin}"
    sunset = "#{shour}h#{smin}"

    # 'main' informations
    humidity = raw["main"]["humidity"]
    pressure = round(raw["main"]["pressure"])
    temp     = Float.round((raw["main"]["temp"] - 273.15), 1) # from Kelvin to Celcius

    # write down our parsed answer
    weather_for_human = [
      "#{name}, #{country}",
      "#{desc}, #{temp}°C #{humidity}% Humidity  #{pressure} hPa",
      "The sun rises at #{sunrise} UTC and sets at #{sunset} UTC"
    ]
    Enum.join(weather_for_human, " ~ ")
  end

end
