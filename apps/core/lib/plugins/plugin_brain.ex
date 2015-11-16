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
      ".forecast" -> forecast(req)
      _           -> nil
    end
  end

  # double_rainbow all the way, what does it even mean?
  defp double_rainbow(req) do
    # TODO parse with an adapt/tensorflow plugin
    req
  end

  defp weather(params, req) do
    Core.PluginWeather.get_current_weather(:core_plugin_weather, params, req)
  end

  defp forecast(_req={uid, _msg}) do
    # TODO provides a ~3h/~3days forecast
    answer = "Not yet implemented."
    Hal.ConnectionHandler.answer(:hal_connection_handler, {uid, [answer]})
  end

end
