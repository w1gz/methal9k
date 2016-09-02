defmodule Core.PluginBrain do
  @moduledoc """
  The brain plugin tries to dispatch the various requests to their appropriate
  process.
  """

  use GenServer
  alias Core.PluginReminder, as: Reminder
  alias Core.PluginWeather, as: Weather
  alias Core.PluginTime, as: Time

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
  defp check_out_the_big_brain_on_brett(req, infos = {msg, _, _}) do
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
    Time.current(:core_plugin_time, params, req)
  end

  defp emojis({uid, frompid}, emoji) do
    answer = case emoji do
               :flip       -> "(╯°□°）╯︵ ┻━┻"
               :shrug      -> "¯\_(ツ)_/¯"
               :disapprove -> "ಠ_ಠ"
               :dealwithit -> "(•_•) ( •_•)>⌐■-■ (⌐■_■)"
             end
    send frompid, {:answer, {uid, [answer]}}
  end

  defp highlight_channel({uid, frompid}, {_msg, from, chan}) do
    answers = case chan do
                nil -> ["This is not a channel"]
                _   -> retrieve_users(frompid, from, chan)
              end
    send frompid, {:answer, {uid, answers}}
  end

  defp retrieve_users(frompid, from, chan) do
    {botname, users} = GenServer.call(frompid, {:get_users, chan})
    answer = users
    |> Enum.filter(&(&1 != from and &1 != botname))
    |> Enum.map_join(" ", &(&1))

    # choose an alternative answer if nobody relevant is found
    case answer do
      "" -> ["#{from}, there is nobody else in this channel."]
      _ -> ["cc " <> answer]
    end
  end

  defp get_reminder(req, infos) do
    Reminder.get(:core_plugin_reminder, req, infos)
  end

  defp weather(params, req = {uid, frompid}) do
    case params do
      [] -> send frompid, {:answer, {uid, ["Missing arguments"]}}
      ["hourly" | arg2] -> Weather.hourly(:core_plugin_weather, arg2, req)
      ["daily" | arg2]  -> Weather.daily(:core_plugin_weather, arg2, req)
      [_city | _]       -> Weather.current(:core_plugin_weather, params, req)
      _ -> send frompid, {:answer, {uid, ["Nope"]}}
    end
  end

  defp help_cmd({uid, frompid}) do
    answers = [
      " .weather <scope?> <city> scope can optionally be hourly or daily",
      " .time <tz or city> tz should follow the 'Country/City' format",
      " .remind <someone> <msg> as soon as he /join this channel",
      " .chan will highlight everyone else in the current channel"
    ]
    send frompid, {:answer, {uid, answers}}
  end

  defp set_reminder(_, {_, frompid}, {_msg, from, nil}) do
    answer = "I can't do that on private messages!"
    send frompid, {:answer, {:privmsg, from, [answer]}}
  end

  defp set_reminder({cmd, user}, req = {_, frompid}, infos) do
    {msg, from, chan} = infos
    case GenServer.call(frompid, {:has_user, chan, user}) do
      true ->
        answer = "#{user} is already on the channel."
        send frompid, {:answer, {chan, from, [answer]}}
      _ ->
        match = Regex.named_captures(~r/#{cmd}.*#{user}(?<memo>.*)/ui, msg)
        reminder = {user, match["memo"]}
        Reminder.set(:core_plugin_reminder, reminder, req, infos)
    end
  end

end
