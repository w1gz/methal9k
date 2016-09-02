defmodule Hal.ConnectionHandler do
  @moduledoc """
  The module will maintain a link to the ExIrc library in order to intercept and
  send message to IRC.
  """

  use GenServer

  # Client
  def start_link(args, opts \\ []) do
    IO.puts "[INFO] New ConnectionHandler"
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Return the current internal state of this module. Useful for sending messages
  directly to the ExIrc process.

  `pid` the pid of the GenServer that will be called.

  ##Example
  ```Elixir
  iex> Hal.ConnectionHandler.get_state(pid)
  ```
  """
  def get_state(pid) do
    GenServer.call(pid, {:get_state})
  end

  @doc """
  Return the list of users in a given IRC `chan`.

  `pid` the pid of the GenServer that will be called.

  `chan` the IRC channel in which you want to retrieve the list of users.

  ##Example
  ```Elixir
  iex> Hal.ConnectionHandler.get_users(pid, "#awesome-chan")
  """
  def get_users(pid, chan) do
    GenServer.call(pid, {:get_users, chan})
  end

  @doc """
  Uses the ExIrc process to send the given `answers` to IRC.

  `pid` the pid of the GenServer that will be called.

  `answer` the IRC channel in which you want to retrieve a list of users.

  ##Example
  ```Elixir
  iex> Hal.ConnectionHandler.answer(pid, ["i'm", "a", "answer"])
  """
  def answer(pid, answers) do
    GenServer.cast(pid, {:answer, answers})
  end

  @doc """
  Check wether the given `user` is present in a specific `chan` or not.

  `pid` the pid of the GenServer that will be called.

  `user` that you want to check the presence.

  `chan` channel in which to look for the `user`.

  ##Example
  ```Elixir
  iex> Hal.ConnectionHandler.has_user(pid, "#awsome-chan", "john")
  """
  def has_user(pid, chan, user) do
    GenServer.call(pid, {:has_user, chan, user})
  end


  # Server callbacks
  def init(state) do
    # Create only one connection per ExIrc.Client
    case ExIrc.Client.is_logged_on? state.client do
      true ->
        ExIrc.Client.add_handler state.client, self()
        send self(), :logged_in
      _ ->
        ExIrc.Client.add_handler state.client, self()
        ExIrc.Client.connect! state.client, state.host, state.port
    end

    uids = Hal.ConnectionHandlerKeeper.give_me_your_table(:hal_connection_handler_keeper)
    new_state = %{state | uids: uids}
    {:ok, new_state}
  end

  def handle_call({:get_state}, _frompid, state) do
    {:reply, state, state}
  end

  def handle_call({:get_users, chan}, _frompid, state) do
    res = {state.nick, ExIrc.Client.channel_users(state.client, chan)}
    {:reply, res, state}
  end

  def handle_call({:has_user, chan, user}, _frompid, state) do
    status = ExIrc.Client.channel_has_user?(state.client, chan, user)
    {:reply, status, state}
  end

  def handle_cast({:answer, {uid, answers}}, state) do
    case :ets.lookup(state.uids, uid) do
      [] -> :ok
      [{_uid, {_msg, from, chan}}] ->
        answer(answers, chan, from, state)
        :ets.delete(state.uids, uid)
    end
    {:noreply, state}
  end

  def handle_cast({:answer, {chan, from, answers}}, state) do
    answer(answers, chan, from, state)
    {:noreply, state}
  end

  def handle_info({:answer, req}, state) do
    Hal.ConnectionHandler.answer(:hal_connection_handler, req)
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
    IO.puts "[INFO] Logged in to the server"
    IO.puts "[INFO] Joining channels:"
    IO.inspect state.chans
    Enum.map(state.chans, &(ExIrc.Client.join state.client, &1))
    {:noreply, state}
  end

  def handle_info({:joined, chan, from}, state) do
    infos = {nil, from.nick, chan}
    uid = give_me_an_id(infos)
    true = :ets.insert(state.uids, {uid, infos})
    Core.PluginBrain.get_reminder(:core_plugin_brain, _req={uid, self()}, _infos={nil,from.nick,chan})
    {:noreply, state}
  end

  def handle_info({:mentioned, msg, from, chan}, state) do
    opts = {msg, from.nick, chan}
    uid = give_me_an_id(opts)
    true = :ets.insert(state.uids, {uid, opts})
    Core.PluginBrain.parse_text(:core_plugin_brain, _req={uid, self()}, {msg,from,chan})
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

  defp generic_received(opts={msg,_from,_chan}, state) do
    case String.at(msg, 0) do
      "." ->
        uid = generate_request(opts, state)
        Core.PluginBrain.command(:core_plugin_brain, _req={uid, self()}, opts)
      _ -> nil
    end
  end

  defp generate_request(opts, state) do
    uid = give_me_an_id(opts)
    true = :ets.insert(state.uids, {uid, opts})
    uid
  end

  defp answer(answers, chan, from, state) do
    Enum.each(answers, &(
          case chan do
            nil -> ExIrc.Client.msg state.client, :privmsg, from, &1 # private_msg
            _   -> ExIrc.Client.msg state.client, :privmsg, chan, &1
          end)
    )
  end

end
