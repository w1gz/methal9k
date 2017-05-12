defmodule Hal.Dispatcher do
  @moduledoc """
  The dispatcher tries to follow up the various requests to their appropriate
  process.
  """

  use GenServer
  alias Hal.Plugin.Quote, as: Quote
  alias Hal.Plugin.Reminder, as: Reminder
  alias Hal.Plugin.Weather, as: Weather
  alias Hal.Plugin.Time, as: Time
  alias Hal.Plugin.Url, as: Url
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
    IO.puts("[NEW] Dispatcher #{inspect self()}")
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
      ".quote"      -> manage_quote(rm_cmd(msg, cmd), req)
      ".chan"       -> highlight_channel(req, infos)
      ".url"        -> url_preview(rm_cmd(msg, cmd), req)
      ".flip"       -> emojis(req, "flip")
      ".shrug"      -> emojis(req, "shrug")
      ".disapprove" -> emojis(req, "disapprove")
      ".dealwithit" -> emojis(req, "dealwithit")
      _             -> nil
    end
  end

  defp rm_cmd(msg, cmd) do
    msg
    |> String.replace_prefix(cmd, "")
    |> String.trim_leading()
  end

  defp help_cmd({uid, frompid} = _req) do
    # dynamically find what Plugin.* modules are loaded
    plugins = with {:ok, module_list} <- :application.get_key(:hal, :modules) do
                Enum.filter(module_list, fn(mod) ->
                  smod = Module.split(mod)
                  length(smod) == 3 and String.match?(Enum.at(smod, 1), ~r/Plugin.*/)
                end)
              end

    # spawn plugins, get their usage and shut them down
    plugins_answers = Enum.map(plugins, fn(module) ->
      [pid] = Herd.launch(:hal_shepherd, [module])
      answer = module.usage(pid)
      Tool.terminate(pid)
      answer
    end)

    orphans = [
      ".chan will highlight everyone else in the current channel"
    ]

    answers = plugins_answers ++ orphans
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

  def manage_quote(quoted_action, req) do
    [quote_id] = Herd.launch(:hal_shepherd, [Quote], __MODULE__, self())
    Quote.manage_quote(quote_id, quoted_action, req)
  end

  # this is only called by the .url command, not the autoparsing one
  defp url_preview(url, req) do
    [url_id] = Herd.launch(:hal_shepherd, [Url], __MODULE__, self())
    Url.preview(url_id, [url], req)
  end

end
