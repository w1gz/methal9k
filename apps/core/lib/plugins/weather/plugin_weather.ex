defmodule Core.PluginWeather do
  use GenServer

  defmodule Credentials do
    defstruct appid: nil
  end

  # Client API
  def start_link(args, opts \\ []) do
    IO.puts("New PluginWeather")
    GenServer.start_link(__MODULE__, args, opts)
  end

  def get_current_weather(pid, params, req) do
    GenServer.cast(pid, {:current_weather, params, req})
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

  def handle_cast({:current_weather, params, req={uid, _msg}}, state) do
    # construct the city name from the parameters
    city = cond do
      params != [] -> Enum.join(params, " ")
      true ->
        answer = "Please give me a location to work with."
        Hal.ConnectionHandler.answer(:hal_connection_handler, {uid, [answer]})
        throw("No arguments for weather, crashing")
    end

    # request some weather informations
    url_api = "api.openweathermap.org/data/2.5/weather"
    query_params = %{q: city, APPID: state.appid}
    {:ok, res} = HTTPoison.get(url_api, [], stream_to: self, params: query_params)
    {:ok, output} = parse_async(res.id)

    # format the answer
    code = output[:code]
    answer = case code do
               200 ->
                 format_for_human(output, req)
               _ ->
                 "¡¡¡ Bonk !!! HTTP.code == #{code}"
             end

    # answer the weather call
    Hal.ConnectionHandler.answer(:hal_connection_handler, {uid, [answer]})
    {:noreply, state}
  end

  def terminate(reason, _state) do
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  defp parse_async(id) do
    parse_async(id, _output = %{:code => "", :data => ""})
  end

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

  defp format_for_human(output, _req={uid, _msg}) do
    json = output[:data]
    raw = Poison.decode!(json)

    # check if the API request was successful
    code = raw["cod"]
    if code != 200 do
      error_msg = raw["message"]
      answer = "The API returns #{code}, #{error_msg}"
        Hal.connectionHandler.answer(:hal_connection_handler, {uid, [answer]})
      throw("The weather api failed to provide a valid answer")
    end

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
    pressure = raw["main"]["pressure"]
    temp     = Float.round((raw["main"]["temp"] - 273.15), 1) # convert from Kelvin to Celcius

    # write down our parsed answer
    weather_for_human = [
      "#{name}, #{country}",
      "#{desc}, #{temp}C  #{humidity}% Humidity  #{pressure} hPa",
      "The sun rises at #{sunrise} UTC and sets at #{sunset} UTC"
    ]
    Enum.join(weather_for_human, " ~~ ")
  end

end
