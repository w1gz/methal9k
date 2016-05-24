defmodule Core.PluginBrain do
  use GenServer

  # Client API
  def start_link(args, opts \\ []) do
    IO.puts("New PluginBrain")
    GenServer.start_link(__MODULE__, args, opts)
  end

  def command(pid, req) do
    GenServer.cast(pid, {:command, req})
  end

  def double_rainbow(pid, req) do
    GenServer.cast(pid, {:double_rainbow, req})
  end

  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:command, req}, state) do
    check_out_the_big_brain_on_brett(req)
    {:noreply, state}
  end

  def handle_cast({:double_rainbow, req}, state) do
    double_rainbow(req)
    {:noreply, state}
  end


  # Internal functions
  defp check_out_the_big_brain_on_brett(req={_uid,msg}) do
    [cmd | params] = String.split(msg)
    case cmd do
      ".weather"  -> weather(params, req)
      ".forecast" -> forecast(params, req)
      _           -> nil
    end
  end

  # double_rainbow all the way, what does it even mean?
  defp double_rainbow(req={_uid, msg}) do
    intent = NLP.Adapt.determine_intent(:nlp_adapt, msg)
    intent = Poison.decode!(intent)
    IO.inspect(intent)          # debug only

    case intent["intent_type"] do
      "WeatherIntent" ->
        location = intent["Location"]
        weather([location], req)
      _ -> nil
    end
  end

  defp weather(params, req) do
    Core.PluginWeather.current_weather(:core_plugin_weather, params, req)
  end

  defp forecast(params, req={uid, _msg}) do
    case params do
      [] ->
        answer = "Please specify the scope and the city."
        Hal.ConnectionHandler.answer(:hal_connection_handler, {uid, [answer]})
        throw(answer)
      [_scope | []] ->
        answer = "Please specify a city."
        Hal.ConnectionHandler.answer(:hal_connection_handler, {uid, [answer]})
        throw(answer)
      ["hourly" | city]  ->
        Core.PluginWeather.hourly(:core_plugin_weather, city, req)
      ["daily" | city] ->
        Core.PluginWeather.daily(:core_plugin_weather, city, req)
      _ ->
        answer = "Please review your scope (hourly or daily)."
        Hal.ConnectionHandler.answer(:hal_connection_handler, {uid, [answer]})
        throw(answer)
    end
  end

end
