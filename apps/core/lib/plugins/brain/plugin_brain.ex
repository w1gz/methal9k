defmodule Core.PluginBrain do
  @moduledoc """
  The brain plugin tries to dispatch the various requests to their appropriate
  process.
  """

  use GenServer

  # Client API
  def start_link(args, opts \\ []) do
    IO.puts("[INFO] New PluginBrain")
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Find the appropriate plugin or process to call depending on the task to do
  (generally determined by the `msg` argument).

  `pid` the pid of the GenServer that will be called.

  `uid` is the unique identifier for this request. Whereas `frompid` is the
  process for which the answer will be sent.

  `msg` initial and complete message (include the command).
  `from` the person who initiated the reminder.
  `chan` the channel on which this happened.

  ## Examples
  ```Elixir
  iex> Core.PluginBrain.command(pid, {uid, frompid}), {msg, from, chan}}
  ```
  """
  def command(pid, req, infos) do
    GenServer.cast(pid, {:command, req, infos})
  end

  @doc """
  Parse the `msg` string and try to make sense of it (Natural Language
  Processing).

  `pid` the pid of the GenServer that will be called.

  `uid` is the unique identifier for this request. Whereas `frompid` is the
  process for which the answer will be sent.

  `msg` initial and complete message (include the command).
  `from` the person who initiated the reminder.
  `chan` the channel on which this happened.

  ## Examples
  ```Elixir
  iex> Core.PluginBrain.parse_text(pid, {uid, frompid}), {msg, from, chan})
  ```
  """
  def parse_text(pid, req, infos) do
    GenServer.cast(pid, {:parse_text, req, infos})
  end


  @doc """
  Forward the call the plugin in charge of retrieving the reminders.

  `pid` the pid of the GenServer that will be called.

  `uid` is the unique identifier for this request. Whereas `frompid` is the
  process for which the answer will be sent.

  `msg` initial and complete message (include the command).
  `from` the person who initiated the reminder.
  `chan` the channel on which this happened.

  ## Examples
  ```Elixir
  iex> Core.PluginBrain.get_reminder(pid, {uid, frompid}), {msg, from, chan})
  ```
  """
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
  defp check_out_the_big_brain_on_brett(req, infos={msg,_from,_chan}) do
    [cmd | params] = String.split(msg)
    case cmd do
      ".help"       -> help_cmd(req)
      ".weather"    -> weather(params, req)
      ".time"       -> time(params, req)
      ".remind"     -> set_reminder({cmd, hd(params)}, req, infos)
      ".chan"       -> highlight_channel(req, infos)
      ".flip"       -> emojis(req, :flip)
      ".shrug"      -> emojis(req, :shrug)
      ".disapprove" -> emojis(req, :disapprove)
      ".dealwithit" -> emojis(req, :dealwithit)
      _             -> nil
    end
  end

  # double_rainbow all the way, what does it even mean?
  defp double_rainbow(req, infos) do
    # TODO parse with a nlp framework (nltk?)
    {req, infos}
  end

  defp time(params, req) do
    Core.PluginTime.current(:core_plugin_time, params, req)
  end

  defp emojis(_req={uid,frompid}, emoji) do
    answer = case emoji do
               :flip       -> "(╯°□°）╯︵ ┻━┻"
               :shrug      -> "¯\_(ツ)_/¯"
               :disapprove -> "ಠ_ಠ"
               :dealwithit -> "(•_•) ( •_•)>⌐■-■ (⌐■_■)"
             end
    send frompid, {:answer, {uid, [answer]}}
  end

  defp highlight_channel(_req={uid,frompid}, _infos={_msg,from,chan}) do
    answers = case chan do
                # avoid private messages
                nil -> ["This is not a channel"]
                _   -> # gather the user list
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
    Core.PluginReminder.get(:core_plugin_reminder, req, infos)
  end

  defp weather(params, req={uid, frompid}) do
    case params do
      [] -> send frompid, {:answer, {uid, ["Missing arguments"]}}
      ["hourly" | arg2] -> Core.PluginWeather.hourly(:core_plugin_weather, arg2, req)
      ["daily" | arg2]  -> Core.PluginWeather.daily(:core_plugin_weather, arg2, req)
      [_city | _]       -> Core.PluginWeather.current(:core_plugin_weather, params, req)
      _ -> send frompid, {:answer, {uid, ["Nope"]}}
    end
  end

  defp help_cmd(_req={uid,frompid}) do
    answers = [" .weather <scope?> <city> scope can optionally be set to hourly or daily",
               " .time <timezone or city> timezone should be in the tz format (i.e. Country/City)",
               " .remind <someone> <msg> as soon as he /join this channel",
               " .chan will highlight everyone else in the current channel"
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

end
