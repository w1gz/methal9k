defmodule Hal.PluginBrain do
  @moduledoc """
  The brain plugin tries to dispatch the various requests to their appropriate
  process.
  """

  use GenServer
  alias Hal.PluginReminder, as: Reminder
  alias Hal.PluginWeather, as: Weather
  alias Hal.PluginTime, as: Time
  alias Hal.Shepherd, as: Herd
  alias Hal.Tool, as: Tool

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @doc """
  Find the appropriate process to call (generally determined by parsing the
  `msg` argument).

  `pid` the pid of the GenServer that will be called.

  `req` is a couple {uid, frompid}. `uid` is the unique identifier for this
  request. Whereas `frompid` is the process for which the answer will be sent.

  `infos` is a 3-tuple {msg, from, chan}. `msg` initial and complete message
  (include the command).  `from` the person who initiated the reminder.  `chan`
  the channel on which this happened.
  """
  def command(pid, req, infos) do
    GenServer.cast(pid, {:command, req, infos})
  end

  # Server callbacks
  def init(args) do
    IO.puts("[NEW] PluginBrain #{inspect self()}")
    {:ok, args}
  end

  def handle_cast({:command, req, infos}, state) do
    check_out_the_big_brain_on_brett(req, infos)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    IO.puts("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  # Internal functions
  defp check_out_the_big_brain_on_brett(req, infos) do
    {msg, _, _, _} = infos
    [cmd | params] = String.split(msg)
    case cmd do
      ".help"       -> help_cmd(req)
      ".weather"    -> weather(params, req)
      ".time"       -> time(params, req)
      ".joined"     -> get_reminder(req, infos)
      ".remind"     -> set_reminder(params, req, infos)
      ".chan"       -> highlight_channel(req, infos)
      ".flip"       -> emojis(req, "flip")
      ".shrug"      -> emojis(req, "shrug")
      ".disapprove" -> emojis(req, "disapprove")
      ".dealwithit" -> emojis(req, "dealwithit")
      _             -> nil
    end
  end

  defp help_cmd(req) do
    {uid, frompid} = req
    answers = [
      " .weather <scope?> <city> scope can optionally be hourly or daily",
      " .time <tz or city> tz should follow the 'Country/City' format",
      " .remind <someone> <msg> as soon as he /join this channel",
      " .chan will highlight everyone else in the current channel"
    ]
    Tool.terminate(self(), frompid, uid, answers)
  end

  defp emojis(req, emoji) do
    {uid, frompid} = req
    answer = case emoji do
               "flip"       -> "(╯°□°）╯︵ ┻━┻"
               "shrug"      -> "¯\_(ツ)_/¯"
               "disapprove" -> "ಠ_ಠ"
               "dealwithit" -> "(•_•) ( •_•)>⌐■-■ (⌐■_■)"
             end
    Tool.terminate(self(), frompid, uid, answer)
  end

  defp highlight_channel(req, infos) do
    {uid, frompid} = req
    {_msg, from, _host, chan} = infos
    answers = case chan do
                nil -> ["This is not a channel"]
                _   -> retrieve_users(frompid, from, chan)
              end
    Tool.terminate(self(), frompid, uid, answers)
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

  defp time(params, req) do
    [time_pid] = Herd.launch(:hal_shepherd, [Time], __MODULE__, self())
    Time.current(time_pid, params, req)
  end

  defp weather(params, req) do
    {uid, frompid} = req
    case params do
      [] -> Tool.terminate(self(), frompid, uid, "Missing arguments")
      ["hourly" | arg2] ->
        [weather_id] = Herd.launch(:hal_shepherd, [Weather], __MODULE__, self())
        Weather.hourly(weather_id, arg2, req)
      ["daily" | arg2] ->
        [weather_id] = Herd.launch(:hal_shepherd, [Weather], __MODULE__, self())
        Weather.daily(weather_id, arg2, req)
      [_city | _] ->
        [weather_id] = Herd.launch(:hal_shepherd, [Weather], __MODULE__, self())
        Weather.current(weather_id, params, req)
      _ -> Tool.terminate(self(), frompid, uid, "Nope")
    end
  end

  defp get_reminder(req, infos) do
    [reminder_id] = Herd.launch(:hal_shepherd, [Reminder], __MODULE__, self())
    Reminder.get(reminder_id, req, infos)
  end

  defp set_reminder(params, req, infos) do
    {_, frompid} = req
    {_msg, from, host, chan} = infos

    # extract user and memo
    user = hd(params)
    memo = Enum.join(tl(params), " ")

    # check if reminder is set from private messages
    case chan do
      nil ->
        answer = "I can't do that on private messages!"
        Tool.terminate(self(), frompid, host, :privmsg, from, answer)
      _ -> nil
    end

    # check if user is already present on the channel
    case GenServer.call(frompid, {:has_user, chan, user}) do
      true ->
        answer = "#{user} is already on the channel."
        Tool.terminate(self(), frompid, host, chan, from, answer)
      _ ->
        # match = Regex.named_captures(~r/#{cmd}.*#{user}(?<memo>.*)/ui, msg)
        # reminder = {user, match["memo"]}
        reminder = {user, memo}
        [remind_id] = Herd.launch(:hal_shepherd, [Reminder], __MODULE__, self())
        Reminder.set(remind_id, reminder, req, infos)
    end

  end

end
