defmodule Hal.IrcHandler do
  @moduledoc """
  The module will maintain a link to the ExIrc library in order to intercept and
  send message to IRC.
  """

  use GenServer
  alias ExIrc.Client, as: IrcClient
  alias Hal.Dispatcher, as: Dispatcher
  alias Hal.IrcHandler, as: IrcHandler
  alias Hal.Shepherd, as: Herd
  alias Hal.Keeper, as: Keeper
  alias Hal.Plugin.Url, as: Url

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
             :ets.new(String.to_atom(args.host),
               [:set,
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
      [{_uid, {_msg, from, _host, chan}}] ->
        answer(answers, chan, from, state)
        :ets.delete(state.uids, uid)
    end
    {:noreply, state}
  end

  def handle_cast({:answer, infos}, state) do
    {_host, chan, from, answers} = infos
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
    Enum.each(state.chans, fn(chan) ->
      IrcClient.join state.client, chan
    end)
    chans = state.chans |> Enum.join(", ")
    IO.puts "[#{state.host}] joining channels: #{chans}"
    {:noreply, state}
  end

  def handle_info({:joined, chan, from}, state) do
    infos = {".joined", from.nick, state.host, chan}
    generic_received(infos, state)
    {:noreply, state}
  end

  def handle_info({:mentioned, _msg, _from, _chan}, state) do
    # do something when somebody mention us?
    {:noreply, state}
  end

  def handle_info({:received, msg, from}, state) do
    infos = {msg, from.nick, state.host, nil}
    generic_received(infos, state)
    {:noreply, state}
  end

  def handle_info({:received, msg, from, chan}, state) do
    infos = {msg, from.nick, state.host, chan}
    generic_received(infos, state)
    {:noreply, state}
  end

  def handle_info({:'ETS-TRANSFER', table_id, owner, module}, state) do
    IO.puts("[ETS] #{inspect table_id} from #{inspect module} #{inspect owner}")
    state = %{state | uids: table_id}
    {:noreply, state}
  end

  def handle_info(_msg, state) do
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
  defp give_me_an_id(infos) do
    {msg, from, host, chan} = infos
    time_seed = UUID.uuid1()
    UUID.uuid5(time_seed, "#{msg}#{from}#{host}#{chan}", :hex)
  end

  defp generic_received(infos, state) do
    {msg, _ ,_ ,_} = infos
    case String.at(msg, 0) do
      "." ->
        uid = generate_request(infos, state)
        [dispatcher_pid] = Herd.launch(:hal_shepherd, [Dispatcher], __MODULE__)
        req = {uid, self()}
        Dispatcher.command(dispatcher_pid, req, infos)
      _ ->
        urls = Regex.scan(~r/https?:\/\/[^\s]+/, msg) |> List.flatten
        case urls do
          [] ->
            nil
          _ ->
            uid = generate_request(infos, state)
            [url_pid] = Herd.launch(:hal_shepherd, [Url], __MODULE__)
            req = {uid, self()}
            Url.preview(url_pid, urls, req)
        end
    end
  end

  defp generate_request(infos, state) do
    uid = give_me_an_id(infos)
    req = {uid, infos}
    true = :ets.insert(state.uids, req)
    uid
  end

  defp answer(answers, chan, from, state) do
    Enum.each(answers, fn(answer) ->
      case chan do
        nil -> IrcClient.msg state.client, :privmsg, from, answer # private_msg
        _   -> IrcClient.msg state.client, :privmsg, chan, answer
      end
    end)
  end

end
