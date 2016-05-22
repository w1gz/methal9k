defmodule Hal.ConnectionHandler do
  use GenServer

  # Client
  def start_link(args, opts \\ []) do
    IO.puts "New ConnectionHandler"
    GenServer.start_link(__MODULE__, args, opts)
  end

  def get_state(pid) do
    GenServer.call(pid, {:get_state})
  end

  def usage(pid, req) do
    GenServer.cast(pid, {:usage, req})
  end

  def answer(pid, answers) do
    GenServer.cast(pid, {:answer, answers})
  end


  # Server callbacks
  def init(state) do
    # Create only one connection per ExIrc.Client
    case ExIrc.Client.is_logged_on? state.client do
      true ->
        ExIrc.Client.add_handler state.client, self
        send self(), :logged_in
      _ ->
        ExIrc.Client.add_handler state.client, self
        ExIrc.Client.connect! state.client, state.host, state.port
    end

    uids = Hal.ConnectionHandlerKeeper.give_me_your_table(:hal_connection_handler_keeper)
    new_state = %{state | uids: uids}
    {:ok, new_state}
  end

  def handle_call({:get_state}, _frompid, state) do
    {:reply, state, state}
  end

  def handle_cast({:usage, _req={uid,_msg}}, state) do
    answers = ["Usage:",
               ".weather <city>",
               ".forecast <city>",
               ".remind <someone> <some_msg> as soon as he /join the current channel"
              ]
    Hal.ConnectionHandler.answer(:hal_connection_handler, _req={uid, answers})
    {:noreply, state}
  end

  def handle_cast({:answer, {uid, answers}}, state) do
    case :ets.lookup(state.uids, uid) do
      [] -> IO.puts("#{uid} not found -- bailing out")
      [{_uid, {_msg, from, chan}}] ->
        Enum.each(answers, fn(answer) ->
          case chan do
            nil -> ExIrc.Client.msg state.client, :privmsg, from, answer # private_msg
            _ -> ExIrc.Client.msg state.client, :privmsg, chan, answer   # chan
          end
        end)
    end

    :ets.delete(state.uids, uid) # delete the finished job from the table
    {:noreply, state}
  end

  def handle_info({:connected, _server, _port}, state) do
    ExIrc.Client.logon state.client, state.pass, state.nick, state.user, state.name
    {:noreply, state}
  end

  def handle_info(:disconnected, state) do
    throw("[ERR] Disconnected from #{state.server}")
    {:noreply, state}
  end

  # ExIrc.client.quit state.client, "I live, I die. I LIVE AGAIN!"
  def handle_info(:logged_in, state) do
    IO.puts "[OK] Logged in to the server"
    IO.puts "[OK] Joining channels:"
    IO.inspect state.chans
    state.chans |> Enum.map(fn(chan) ->
      ExIrc.Client.join state.client, chan
      ExIrc.Client.msg state.client, :privmsg, chan, "I live, I die. I LIVE AGAIN!"
    end)

    {:noreply, state}
  end

  def handle_info({:joined, chan, from}, state) do
    opts = {nil, from.nick, chan}
    uid = give_me_an_id(opts)
    true = :ets.insert(state.uids, {uid, opts})
    get_reminder(_infos={chan, from.nick}, _req={uid, opts})
    {:noreply, state}
  end

  def handle_info({:mentioned, msg, from, chan}, state) do
    opts = {msg, from.nick, chan}
    uid = give_me_an_id(opts)
    true = :ets.insert(state.uids, {uid, opts})
    Core.PluginBrain.double_rainbow(:core_plugin_brain, _req={uid, msg})
    {:noreply, state}
  end

  def handle_info({:received, msg, from}, state) do
    generic_received(_opts={msg, from.nick, nil}, state)
    {:noreply, state}
  end

  def handle_info({:received, msg, from, chan}, state) do
    generic_received(_opts={msg, from.nick, chan}, state)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    # debug only
    # IO.inspect(msg)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end


  # Internal functions
  defp give_me_an_id(_opts={msg, from, chan}) do
    time_seed = UUID.uuid1()
    UUID.uuid5(time_seed, "#{msg}#{from}#{chan}", :hex)
  end

  defp help(req) do
    Hal.ConnectionHandler.usage(:hal_connection_handler, req)
  end

  defp generic_received(opts={msg,_from,_chan}, state) do
    if String.at(msg, 0) == "." do
      uid = give_me_an_id(opts)
      true = :ets.insert(state.uids, {uid, opts})

      [cmd | params] = String.split(msg)
      case cmd do
        ".help"   -> help(_req={uid,msg})
        ".remind" ->
          set_reminder(_parsed={cmd, hd(params)}, opts, _req={uid,msg}, state)
        _ -> Core.PluginBrain.command(:core_plugin_brain, _req={uid, msg})
      end
    end
  end

  defp set_reminder(_parsed={cmd, user}, opts={msg,from,chan}, req, state) do
    case chan do
      nil -> ExIrc.Client.msg state.client, :privmsg, from, "I can't do that on private messages!"
      _ ->
        # only store the reminder for a missing nickname
        case ExIrc.Client.channel_has_user?(state.client, chan, user) do
          true -> ExIrc.Client.msg state.client, :privmsg, chan, "#{user} is already on the channel, tell him yourself ! :)"
          _ ->
            match = Regex.named_captures(~r/#{cmd}.*#{user}(?<memo>.*)/ui, msg)
            Hal.PluginReminder.set_reminder(:hal_plugin_reminder, _reminder = {user, match["memo"]}, opts, req)
        end
    end
  end

  defp get_reminder(infos, req) do
    Hal.PluginReminder.remind_someone(:hal_plugin_reminder, infos, req)
  end

end
