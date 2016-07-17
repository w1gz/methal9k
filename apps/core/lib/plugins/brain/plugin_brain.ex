defmodule Core.PluginBrain do
  use GenServer

  # Client API
  def start_link(args, opts \\ []) do
    IO.puts("[INFO] New PluginBrain")
    GenServer.start_link(__MODULE__, args, opts)
  end

  def command(pid, req, infos) do
    GenServer.cast(pid, {:command, req, infos})
  end

  def user_action(pid, req, infos) do
    GenServer.cast(pid, {:user_action, req, infos})
  end

  def parse_text(pid, req, infos) do
    GenServer.cast(pid, {:parse_text, req, infos})
  end

  def get_reminder(pid, req, infos) do
    GenServer.cast(pid, {:get_reminder, req, infos})
  end


  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:command, req, infos}, state) do
    check_out_the_big_brain_on_brett(req, infos)
    {:noreply, state}
  end

  def handle_cast({:user_action, req, infos}, state) do
    big_kahuna_burger(req, infos)
    {:noreply, state}
  end

  def handle_cast({:parse_text, req, infos}, state) do
    double_rainbow(req, infos)
    {:noreply, state}
  end

  def handle_cast({:get_reminder, req, infos}, state) do
    get_reminder(req, infos)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end


  # Internal functions
  defp check_out_the_big_brain_on_brett(req, _infos={msg,_from,_chan}) do
    [cmd | params] = String.split(msg)
    case cmd do
      ".help"     -> help_cmd(req)
      ".weather"  -> weather(params, req)
      ".forecast" -> forecast(params, req)
      _           -> nil
    end
  end

  defp big_kahuna_burger(req, infos={msg,_from,_chan}) do
    [cmd | params] = String.split(msg)
    case cmd do
      "@help"    -> help_user(req)
      "@remind"  -> set_reminder({cmd, hd(params)}, req, infos)
      "@chan"    -> highlight_channel(req, infos)
      _          -> nil
    end
  end

  # double_rainbow all the way, what does it even mean?
  defp double_rainbow(req, infos) do
    # TODO parse with a nlp framework (nltk?)
    {req, infos}
  end

  defp highlight_channel(_req={uid,frompid}, _infos={_msg,from,chan}) do
    answers = case chan do
                nil ->          # avoid private messages
                  ["This is not a channel"]
                _   ->          # gather the user list
                  {botname, users} = GenServer.call(frompid, {:get_users, chan})
                  answer = Enum.filter(users, &(&1 != from and &1 != botname))
                  |> Enum.map_join(" ", &(&1))

                  # alternative answer if nobody relevant is found
                  answers = case answer do
                              "" -> ["#{from}, there is nobody else in this channel."]
                              _ -> ["cc " <> answer]
                            end
              end
    send frompid, {:answer, {uid, answers}}
  end

  defp get_reminder(req, infos) do
    Core.PluginReminder.remind_someone(:core_plugin_reminder, req, infos)
  end

  defp weather(params, req) do
    Core.PluginWeather.current_weather(:core_plugin_weather, params, req)
  end

  defp help_cmd(_req={uid,frompid}) do
    answers = ["Commands (see also @help):",
               ".weather <city>",
               ".forecast <scope> <city> (scope can be either 'hourly' or 'daily')"
              ]
    send frompid, {:answer, {uid, answers}}
  end

  defp help_user(_req={uid,frompid}) do
    answers = ["User actions (see also .help):",
               "@remind <someone> <msg> as soon as he /join this channel",
               "@chan will highlight everyone else in the current channel"
              ]
    send frompid, {:answer, {uid, answers}}
  end

  defp set_reminder(_parsed={cmd, user}, req={_uid,frompid}, infos={msg,from,chan}) do
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
            Core.PluginReminder.set_reminder(:core_plugin_reminder, _reminder = {user, match["memo"]}, req, infos)
        end
    end
  end

  defp forecast(params, req={uid, frompid}) do
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
