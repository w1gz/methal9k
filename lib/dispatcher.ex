defmodule Hal.Dispatcher do
  @moduledoc """
  The dispatcher tries to follow up the various requests to their appropriate
  process.
  """

  use GenServer
  require Logger
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
  """
  def command(pid, infos) do
    GenServer.cast(pid, {:command, infos})
  end

  # Server callbacks
  def init(args) do
    Logger.debug("[NEW] Dispatcher #{inspect self()}")
    {:ok, args}
  end

  def handle_cast({:command, infos}, state) do
    check_out_the_big_brain_on_brett(infos)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.debug("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  # Internal functions
  defp check_out_the_big_brain_on_brett(infos) do
    [cmd | params] = String.split(infos.msg)
    case cmd do
      ".help"       -> help_cmd(infos)
      ".weather"    -> weather(params, infos)
      ".time"       -> time(params, infos)
      ".joined"     -> get_reminder(infos)
      ".remind"     -> set_reminder(params, infos)
      ".quote"      -> manage_quote(rm_cmd(infos.msg, cmd), infos)
      ".chan"       -> highlight_channel(infos)
      ".url"        -> url_preview(rm_cmd(infos.msg, cmd), infos)
      ".wtf"        -> emojis(String.slice(cmd, 1..-1), infos)
      ".yay"        -> emojis(String.slice(cmd, 1..-1), infos)
      ".flip"       -> emojis(String.slice(cmd, 1..-1), infos)
      ".shrug"      -> emojis(String.slice(cmd, 1..-1), infos)
      ".disapprove" -> emojis(String.slice(cmd, 1..-1), infos)
      ".dealwithit" -> emojis(String.slice(cmd, 1..-1), infos)
      ".bow"        -> emojis(String.slice(cmd, 1..-1), infos)
      _             -> nil
    end
  end

  defp rm_cmd(msg, cmd) do
    msg
    |> String.replace_prefix(cmd, "")
    |> String.trim_leading()
  end

  defp help_cmd(infos) do
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
    Tool.terminate(self(), infos.pid, infos.uid, answers)
  end

  defp emojis(emoji, infos) do
    answer = case emoji do
               "wtf"        -> "(⊙＿⊙')"
               "yay"        -> "\\( ﾟヮﾟ)/"
               "flip"       -> "(╯°□°）╯︵ ┻━┻"
               "shrug"      -> "¯\\_(ツ)_/¯"
               "disapprove" -> "ಠ_ಠ"
               "dealwithit" -> "(•_•) ( •_•)>⌐■-■ (⌐■_■)"
               "bow"        -> "¬¬"
             end
    Tool.terminate(self(), infos.pid, infos.uid, answer)
  end

  defp highlight_channel(infos) do
    answers = case infos.chan do
                nil -> ["This is not a channel"]
                _   -> retrieve_users(infos.pid, infos.from, infos.chan)
              end
    Tool.terminate(self(), infos.pid, infos.uid, answers)
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

  defp time(params, infos) do
    [time_pid] = Herd.launch(:hal_shepherd, [Time], __MODULE__, self())
    Time.current(time_pid, params, infos)
  end

  defp weather(params, infos) do
    case params do
      [] -> Tool.terminate(self(), infos.pid, infos.uid, "Missing arguments")
      ["hourly" | arg2] ->
        [weather_id] = Herd.launch(:hal_shepherd, [Weather], __MODULE__, self())
        Weather.hourly(weather_id, arg2, infos)
      ["daily" | arg2] ->
        [weather_id] = Herd.launch(:hal_shepherd, [Weather], __MODULE__, self())
        Weather.daily(weather_id, arg2, infos)
      [_city | _] ->
        [weather_id] = Herd.launch(:hal_shepherd, [Weather], __MODULE__, self())
        Weather.current(weather_id, params, infos)
      _ -> Tool.terminate(self(), infos.pid, infos.uid, "Nope")
    end
  end

  defp get_reminder(infos) do
    [reminder_id] = Herd.launch(:hal_shepherd, [Reminder], __MODULE__, self())
    Reminder.get(reminder_id, infos)
  end

  defp set_reminder(params, infos) do
    with :ok <- reminder_refuse_priv_msg(infos),
         {:ok, user, memo} <- reminder_extract_params(params),
           false <- reminder_chan_has_user(user, infos) do
      # match = Regex.named_captures(~r/#{cmd}.*#{user}(?<memo>.*)/ui, msg)
      # reminder = {user, match["memo"]}
      [remind_id] = Herd.launch(:hal_shepherd, [Reminder], __MODULE__, self())
      Reminder.set(remind_id, {user, memo}, infos)
    else
      {:error, msg} -> Tool.terminate(self(), infos.pid, infos.uid, msg)
    end
  end

  defp reminder_refuse_priv_msg(infos) do
    case infos.chan do
      nil -> {:error, "I can't do that on private messages!"}
      _ -> :ok
    end
  end

  defp reminder_extract_params(params) do
    case params do
      [] -> {:error, "Missing parameter, type .help for usage."}
      [head|tail] -> {:ok, head, Enum.join(tail, " ")}
    end
  end

  defp reminder_chan_has_user(user, infos) do
    case GenServer.call(infos.pid, {:has_user, infos.chan, user}) do
      true -> {:error, "#{user} is already on the channel."}
      false -> false
    end
  end

  defp manage_quote(quoted_action, infos) do
    [quote_id] = Herd.launch(:hal_shepherd, [Quote], __MODULE__, self())
    Quote.manage_quote(quote_id, quoted_action, infos)
  end

  # this is only called by the .url command, not the autoparsing one
  defp url_preview(url, infos) do
    [url_id] = Herd.launch(:hal_shepherd, [Url], __MODULE__, self())
    Url.preview(url_id, [url], infos)
  end

end
