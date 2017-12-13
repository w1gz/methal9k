defmodule Hal.Plugin.Weather do
  @moduledoc """
  Provide facility for weather and forecast informations.
  """

  use GenServer
  require Logger
  alias Hal.Tool, as: Tool
  alias Hal.CommonHandler, as: Handler

  defmodule Credentials do
    @moduledoc """
    Holds the token for talking to the weather API.
    """

    defstruct appid: nil
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def usage(pid) do
    GenServer.call(pid, :usage)
  end

  def current(pid, params, infos) do
    GenServer.cast(pid, {:current, params, infos})
  end

  @doc """
  Fetch a 5-day forecast with intervals of 3 hours. Only the 4 first answers are
  returned. Which means if you ask the weather at 12:00, you'll get the weather
  for:
  - 12:00
  - 15:00
  - 18:00
  - 21:00

  `pid` the pid of the GenServer that will be called.

  `params` list of string containing the location.
  """
  def hourly(pid, params, infos) do
    GenServer.cast(pid, {:forecast_hourly, params, infos})
  end

  @doc """
  Fetch a 12-day forecast with intervals of 1 day. Only the 4 first answers are
  returned. Which means if you ask the weather for monday the 10th, you'll get
  the weather for:
  - monday 10th
  - tuesday 11th
  - wednesday 12th
  - Thursday 13th

  `pid` the pid of the GenServer that will be called.

  `params` list of string containing the location.
  """
  def daily(pid, params, infos) do
    GenServer.cast(pid, {:forecast_daily, params, infos})
  end

  def init(_state) do
    Logger.debug("[NEW] PluginWeather #{inspect self()}")
    filename = "lib/plugins/weather/weather_token.sec"
    weather_id = Tool.read_token(filename)
    state = %Credentials{appid: weather_id}
    {:ok, state}
  end

  def handle_call(:usage, _frompid, state) do
    answer = ".weather <scope>? <city> scope can optionally be hourly or daily"
    {:reply, answer, state}
  end

  def handle_cast(args = {:current, _params, _infos}, state) do
    url = "api.openweathermap.org/data/2.5/weather"
    get_weather(args, state.appid, url)
    {:noreply, state}
  end

  def handle_cast(args = {:forecast_hourly, _params, _infos}, state) do
    url = "api.openweathermap.org/data/2.5/forecast"
    get_weather(args, state.appid, url)
    {:noreply, state}
  end

  def handle_cast(args = {:forecast_daily, _params, _infos}, state) do
    url = "api.openweathermap.org/data/2.5/forecast/daily"
    get_weather(args, state.appid, url)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.debug("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  defp get_weather({type, params, infos}, appid, url) do
    json = send_request(params, infos, appid, url)
    answers = format_for_human(json, infos, type)
    infos = %Handler.Infos{infos | answers: answers}
    Handler.terminate(infos)
  end

  defp send_request(params, infos, appid, url) do
    # request some weather informations
    city = Enum.join(params, " ")
    query_params = %{q: city, dt: "UTC", units: "metric", APPID: appid}
    res = HTTPoison.get!(url, [], params: query_params)
    case res.status_code do
      200 -> res.body
      _ ->
        answer = "HTTP Request failed with #{res.status_code}"
        infos = %Handler.Infos{infos | answers: [answer]}
        Handler.terminate(infos)     # let it crash
    end
  end

  defp format_for_human(json, infos, weather_type) do
    raw = Poison.decode!(json)

    # The API will either return a integer or a string
    raw_code = raw["cod"]
    code = case is_integer(raw_code) do
             true -> raw_code
             false -> String.to_integer(raw_code)
           end

    # check if the API request was successful
    if code != 200 do
      error_msg = raw["message"]
      answer = "The API returns #{code}, #{error_msg}"
      infos = %Handler.Infos{infos | answers: [answer]}
      Handler.terminate(infos)     # let it crash
    else
      case weather_type do
        :current         -> [pretty_print(raw, fun_current())] # 'member, we need to return a list
        :forecast_hourly -> format_forecast(raw, fun_hourly())
        :forecast_daily  -> format_forecast(raw, fun_daily())
      end
    end
  end

  defp pretty_print(raw, fun_format) do
    desc = hd(raw["weather"])["description"]
    one_unit = List.insert_at(fun_format.(raw), -1, desc)
    Enum.join(one_unit, " ~ ")
  end

  defp format_forecast(raw, {fun_forecast, fun_filter}) do
    filtered = Enum.filter(raw["list"], fun_filter)
    format_forecast(raw, filtered, fun_forecast)
  end

  defp format_forecast(raw, filtered, fun_forecast) do
    # format our weather
    answers = filtered
    |> Enum.take(4)
    |> Enum.map(&(pretty_print(&1, fun_forecast)))

    # add the forecast header
    name = raw["city"]["name"]
    country = raw["city"]["country"]
    header = "#{name}, #{country}."
    List.insert_at(answers, 0, header)
  end

  defp fun_hourly do
    filter = fn(fcst) ->
      {:ok, hnow} = Timex.format(Timex.now, "%H", :strftime)
      {_, {hour,_,_}} = :calendar.gregorian_seconds_to_datetime(fcst["dt"])
      hnow >= hour
    end

    hourly = fn(fcst) ->
      # general conditions
      datetime = fcst["dt_txt"]
      temp = round(fcst["main"]["temp"])
      pressure = round(fcst["main"]["pressure"])

      # construct the answer
      ["#{datetime} UTC", "#{pressure} hPa, #{temp}°C"]
    end

    {hourly, filter}
  end

  defp fun_daily do
    filter = fn(_) -> true end

    daily = fn(fcst) ->
      time = fcst["dt"]
      {{year, month, day}, _} = :calendar.gregorian_seconds_to_datetime(time)

      # temps of the day
      tmorn = round(fcst["temp"]["morn"])
      teve = round(fcst["temp"]["eve"])
      tnight = round(fcst["temp"]["night"])

      # general conditions
      pressure = round(fcst["pressure"])

      # construct the answer
      [
        "#{year+1970}-#{month}-#{day}",
        "#{pressure} hPa",
        "#{tmorn}°C #{teve}°C #{tnight}°C",
      ]
    end

    {daily, filter}
  end

  defp fun_current do
    fn(raw) ->
      # 'basic' weather & name
      name = raw["name"]

      # 'sys' complementary infos
      country = raw["sys"]["country"]

      # 'main' informations
      humidity = raw["main"]["humidity"]
      cloud = raw["clouds"]["all"]
      pressure = round(raw["main"]["pressure"])
      temp = round(raw["main"]["temp"])

      # construct the answer
      [
        "#{name}, #{country}" ,
        "#{humidity}% Humidity #{cloud}% cloudiness #{pressure} hPa #{temp}°C"
      ]
    end
  end

end
