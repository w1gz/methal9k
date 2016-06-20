defmodule Core.PluginBrain do
  use GenServer

  # Client API
  def start_link(args, opts \\ []) do
    IO.puts("[INFO] New PluginBrain")
    GenServer.start_link(__MODULE__, args, opts)
  end

  def usage(pid, req) do
    GenServer.cast(pid, {:usage, req})
  end

  def command(pid, opts, req) do
    GenServer.cast(pid, {:command, opts, req})
  end

  def get_reminder(pid, infos, req) do
    GenServer.cast(pid, {:get_reminder, infos, req})
  end

  def double_rainbow(pid, req) do
    GenServer.cast(pid, {:double_rainbow, req})
  end

  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:command, opts, req}, state) do
    check_out_the_big_brain_on_brett(opts, req)
    {:noreply, state}
  end

  def handle_cast({:get_reminder, infos, req}, state) do
    get_reminder(infos, req)
    {:noreply, state}
  end

  def handle_cast({:double_rainbow, req}, state) do
    double_rainbow(req)
    {:noreply, state}
  end

  def handle_cast({:usage, req}, state) do
    help(req)
    {:noreply, state}
  end


  # Internal functions
  defp check_out_the_big_brain_on_brett(opts, req={_uid,_frompid,msg}) do
    [cmd | params] = String.split(msg)
    case cmd do
      ".help"   -> help(req)
      ".weather"  -> weather(params, req)
      ".forecast" -> forecast(params, req)
      ".remind"   -> set_reminder({cmd, hd(params)}, opts, req)
      _           -> nil
    end
  end

  # double_rainbow all the way, what does it even mean?
  defp double_rainbow(req) do
    # TODO parse with a nlp framework (nltk?)
    req
  end

  defp get_reminder(infos, req) do
    Core.PluginReminder.remind_someone(:core_plugin_reminder, infos, req)
  end

  defp weather(params, req) do
    Core.PluginWeather.current_weather(:core_plugin_weather, params, req)
  end

  defp help(_req={uid,frompid,_msg}) do
    answers = ["Usage:",
               ".weather <city>",
               ".forecast <scope> <city> (scope can be either 'hourly' or 'daily')",
               ".remind <someone> <msg> as soon as he /join this channel"
              ]
    send frompid, {:answer, {uid, answers}}
  end

  defp set_reminder(_parsed={cmd, user}, opts={msg,from,chan}, req={_uid,frompid,msg}) do
    case chan do
      nil ->
        answer = "I can't do that on private messages!"
        send frompid, {:answer, {:privmsg, from, [answer]}}
      _ ->
        case GenServer.call(frompid, {:has_user, chan, user}) do
          true ->
            answer = "#{user} is already on the channel."
            send frompid, {:answer, {chan, from, [answer]}}
          _ ->
            match = Regex.named_captures(~r/#{cmd}.*#{user}(?<memo>.*)/ui, msg)
            Core.PluginReminder.set_reminder(:core_plugin_reminder, _reminder = {user, match["memo"]}, opts, req)
        end
    end
  end

  defp forecast(params, req={uid, frompid, _msg}) do
    case params do
      [] ->
        answer = "Please specify the scope and the city."
        send frompid, {:answer, {uid, [answer]}}
        throw(answer)
      [_scope | []] ->
        answer = "Please specify a city."
        send frompid, {:answer, {uid, [answer]}}
        throw(answer)
      ["hourly" | city]  ->
        Core.PluginWeather.hourly(:core_plugin_weather, city, req)
      ["daily" | city] ->
        Core.PluginWeather.daily(:core_plugin_weather, city, req)
      _ ->
        answer = "Please review your scope (hourly or daily)."
        send frompid, {:answer, {uid, [answer]}}
        throw(answer)
    end
  end

end
