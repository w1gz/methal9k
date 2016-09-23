defmodule Hal.IrcHandler do
  @moduledoc """
  The module will maintain a link to the ExIrc library in order to intercept and
  send message to IRC.
  """

  use GenServer
  alias ExIrc.Client, as: IrcClient
  alias Hal.PluginBrain, as: Brain
  alias Hal.IrcHandler, as: IrcHandler
  alias Hal.Shepherd, as: Herd
  alias Hal.Keeper, as: Keeper

  # Client
  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Return the current internal state of this module. Useful for sending messages
  directly to the ExIrc process.

  `pid` the pid of the GenServer that will be called.
  """
  def get_state(pid) do
    GenServer.call(pid, {:get_state})
  end

  @doc """
  Return the list of users in a given IRC `chan`.

  `pid` the pid of the GenServer that will be called.

  `chan` the IRC channel in which you want to retrieve the list of users.
  """
  def get_users(pid, chan) do
    GenServer.call(pid, {:get_users, chan})
  end

  @doc """
  Uses the ExIrc process to send the given `answers` to IRC.

  `pid` the pid of the GenServer that will be called.

  `uid` of the job asking for these answers

  `answer` the IRC channel in which you want to retrieve a list of users.
  """
  def answer(pid, answers) do
    GenServer.cast(pid, {:answer, answers})
  end

  @doc """
  Check wether the given `user` is present in a specific `chan` or not.

  `pid` the pid of the GenServer that will be called.

  `user` that you want to check the presence.

  `chan` channel in which to look for the `user`.
  """
  def has_user(pid, chan, user) do
    GenServer.call(pid, {:has_user, chan, user})
  end

  # Server callbacks
  def init(args) do
    IO.puts "[NEW] IrcHandler #{inspect self()}"
    case IrcClient.is_logged_on? args.client do
      true ->
        IrcClient.add_handler args.client, self()
        send self(), :logged_in
      _ ->
        IrcClient.add_handler args.client, self()
        IrcClient.connect! args.client, args.host, args.port
    end

    uids = case Keeper.give_me_your_table(:hal_keeper, __MODULE__) do
             true -> nil # we will receive this by ETS-TRANSFER later on
             _ -> hal_pid = Process.whereis(:hal_keeper)
             :ets.new(:irc_handler_ets, [:set,
                                         :private,
                                         {:heir, hal_pid, __MODULE__}])
           end
    state = %{args | uids: uids}
    {:ok, state}
  end

  def handle_call({:get_state}, _frompid, state) do
    {:reply, state, state}
  end

  def handle_call({:get_users, chan}, _frompid, state) do
    res = {state.nick, IrcClient.channel_users(state.client, chan)}
    {:reply, res, state}
  end

  def handle_call({:has_user, chan, user}, _frompid, state) do
    status = IrcClient.channel_has_user?(state.client, chan, user)
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
    IrcHandler.answer(self(), req)
    {:noreply, state}
  end

  def handle_info({:connected, server, port}, state) do
    IO.puts("[INFO] connecting to #{server}:#{port}")
    IrcClient.logon state.client, state.pass, state.nick, state.user, state.name
    {:noreply, state}
  end

  def handle_info(:disconnected, state) do
    throw("[ERR] Disconnected from #{state.host}")
    {:noreply, state}
  end

  # ExIrc.client.quit state.client, "I live, I die. I LIVE AGAIN!"
  def handle_info(:logged_in, state) do
    IO.puts "[INFO] joining channels:"
    Enum.each(state.chans, fn(chan) ->
      IO.puts(chan)
      IrcClient.join state.client, chan
    end)

    {:noreply, state}
  end

  def handle_info({:joined, chan, from}, state) do
    infos = {nil, from.nick, chan}
    uid = give_me_an_id(infos)
    true = :ets.insert(state.uids, {uid, infos})
    # TODO convert {set|get}_reminder to handle_cast?
    [brain_pid] = Herd.launch(:hal_shepherd, [Brain], __MODULE__)
    Brain.get_reminder(brain_pid, {uid, self()}, {nil,from.nick,chan})
    {:noreply, state}
  end

  def handle_info({:mentioned, _msg, _from, _chan}, state) do
    # TODO do something about this mention
    # opts = {msg, from.nick, chan}
    # uid = give_me_an_id(opts)
    # true = :ets.insert(state.uids, {uid, opts})
    # [brain_pid] = Herd.launch(:hal_shepherd, [Brain], __MODULE__)
    # Brain.parse_text(brain_pid, {uid, self()}, {msg,from,chan})
    {:noreply, state}
  end

  def handle_info({:received, msg, from}, state) do
    generic_received({msg, from.nick, nil}, state)
    {:noreply, state}
  end

  def handle_info({:received, msg, from, chan}, state) do
    generic_received({msg, from.nick, chan}, state)
    {:noreply, state}
  end

  def handle_info({:'ETS-TRANSFER', table_id, owner, module}, state) do
    IO.puts("[ETS] #{inspect table_id} from #{inspect module} #{inspect owner}")
    state = %{state | uids: table_id}
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    # IO.inspect(msg)
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
  defp give_me_an_id({msg, from, chan}) do
    time_seed = UUID.uuid1()
    UUID.uuid5(time_seed, "#{msg}#{from}#{chan}", :hex)
  end

  defp generic_received(opts = {msg, _from, _chan}, state) do
    case String.at(msg, 0) do
      "." ->
        uid = generate_request(opts, state)
        [brain_pid] = Herd.launch(:hal_shepherd, [Brain], __MODULE__)
        Brain.command(brain_pid, {uid, self()}, opts)
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
            nil -> IrcClient.msg state.client, :privmsg, from, &1 # private_msg
            _   -> IrcClient.msg state.client, :privmsg, chan, &1
          end)
    )
  end

end
