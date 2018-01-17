defmodule Hal.Dispatcher do
  @moduledoc """
  The dispatcher tries to follow up the various requests to their appropriate
  process.
  """

  use GenServer
  require Logger
  alias Hal.Plugin.Quote, as: Quote
  alias Hal.Plugin.Bouncer, as: Bouncer
  alias Hal.Plugin.Weather, as: Weather
  alias Hal.Plugin.Time, as: Time
  alias Hal.Plugin.Web, as: Web
  alias Hal.CommonHandler, as: Handler

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def command(pid, infos) do
    GenServer.cast(pid, {:command, infos})
  end

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

  defp check_out_the_big_brain_on_brett(infos) do
    [cmd | params] = String.split(infos.msg)
    case cmd do
      ".help"       -> help_cmd(infos)
      ".weather"    -> weather(params, infos)
      ".time"       -> time(params, infos)
      ".joined"     -> get_bouncer(infos)
      ".bounce"     -> set_bouncer(params, infos)
      ".quote"      -> manage_quote(rm_cmd(infos.msg, cmd), infos)
      ".chan"       -> highlight_channel(infos)
      ".web"        -> web_search(rm_cmd(infos.msg, cmd), infos)
      _             -> emojis(cmd, infos)
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
      :poolboy.transaction(module, fn(pid) ->
        module.usage(pid)
      end)
    end)

    orphans = [
      ".chan highlight everyone else in the current channel (IRC only)"
    ]

    answers = plugins_answers ++ orphans
    infos = %Handler.Infos{infos | answers: answers}
    Handler.terminate(infos)
  end

  defp emojis(emoji, infos) do
    answer = case emoji do
               ".wtf"        -> "(⊙＿⊙')"
               ".wtf2"       -> "(ʘ _ ʘ)"
               ".wtf3"       -> "(ʘ _ ⚆)"
               ".yay"        -> "\\( ﾟヮﾟ)/"
               ".tableflip"  -> "(╯°□°）╯︵ ┻━┻"
               ".flip"       -> "┬──┬◡ﾉ(° -°ﾉ)"
               ".shrug"      -> "¯\\_(ツ)_/¯"
               ".disapprove" -> "ಠ_ಠ"
               ".dealwithit" -> "(•_•) ( •_•)>⌐■-■ (⌐■_■)"
               ".bow"        -> "¬¬"
               ".gwaby"      -> "^(;,;)^"
               ".doit"       -> "(☞ﾟヮﾟ)☞"
               ".doit2"      -> "☜(ﾟヮﾟ☜)"
               ".dunno"      -> "┐('～`；)┌"
               _             -> nil
             end
    infos = %Handler.Infos{infos | answers: [answer]}
    Handler.terminate(infos, :me)
  end

  defp highlight_channel(infos) do
    answer = case infos.chan do
               nil -> "This is not a channel"
               _   -> retrieve_users(infos.pid, infos.from, infos.chan)
             end
    infos = %Handler.Infos{infos | answers: [answer]}
    Handler.terminate(infos)
  end

  defp retrieve_users(frompid, from, chan) do
    {botname, users} = GenServer.call(frompid, {:get_users, chan})
    answer = users
    |> Enum.filter(&(&1 != from and &1 != botname))
    |> Enum.map_join(" ", &(&1))

    # choose an alternative answer if nobody relevant is found
    case answer do
      "" -> "#{from}, there is nobody else in this channel."
      _ -> "cc " <> answer
    end
  end

  defp time(params, infos) do
    :poolboy.transaction(Time, fn(pid) ->
      Time.current(pid, params, infos)
    end)
  end

  defp weather(params, infos) do
    case params do
      [] ->
        infos = %Handler.Infos{infos | answers: ["Missing arguments"]}
        Handler.terminate(infos)
      ["hourly" | arg2] ->
        :poolboy.transaction(Weather, fn(pid) ->
          Weather.hourly(pid, arg2, infos)
        end)
      ["daily" | arg2] ->
        :poolboy.transaction(Weather, fn(pid) ->
          Weather.daily(pid, arg2, infos)
        end)
      [_city | _] ->
        :poolboy.transaction(Weather, fn(pid) ->
          Weather.current(pid, params, infos)
        end)
      _ ->
        infos = %Handler.Infos{infos | answers: ["Nope"]}
        Handler.terminate(infos)
    end
  end

  defp get_bouncer(infos) do
    :poolboy.transaction(Bouncer, fn(pid) ->
      Bouncer.get(pid, infos)
    end)
  end

  defp set_bouncer(params, infos) do
    with :ok <- bouncer_refuse_priv_msg(infos),
         {:ok, user, memo} <- bouncer_extract_params(params),
           false <- bouncer_chan_has_user(user, infos) do
      # match = Regex.named_captures(~r/#{cmd}.*#{user}(?<memo>.*)/ui, msg)
      # bouncer = {user, match["memo"]}
      :poolboy.transaction(Bouncer, fn(pid) ->
        Bouncer.set(pid, {user, memo}, infos)
      end)
    else
      {:error, msg} ->
        infos = %Handler.Infos{infos | answers: [msg]}
      Handler.terminate(infos)
    end
  end

  defp bouncer_refuse_priv_msg(infos) do
    case infos.chan do
      nil -> {:error, "I can't do that on private messages!"}
      _ -> :ok
    end
  end

  defp bouncer_extract_params(params) do
    case params do
      [] -> {:error, "Missing parameter, type .help for usage."}
      [head|tail] -> {:ok, head, Enum.join(tail, " ")}
    end
  end

  defp bouncer_chan_has_user(user, infos) do
    case GenServer.call(infos.pid, {:has_user, infos.chan, user}) do
      true -> {:error, "#{user} is already on the channel."}
      false -> false
    end
  end

  defp manage_quote(quoted_action, infos) do
    :poolboy.transaction(Quote, fn(pid) ->
      Quote.manage_quote(pid, quoted_action, infos)
    end)
  end

  # this is only called by the .web command, not the autoparsing one
  defp web_search(params, infos) do
    :poolboy.transaction(Web, fn(pid) ->
      Web.search(pid, params, infos)
    end)
  end

end
