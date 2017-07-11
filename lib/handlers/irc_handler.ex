defmodule Hal.IrcHandler do
  @moduledoc """
  The module will maintain a link to the ExIrc library in order to intercept and
  send message to IRC.
  """

  use GenServer
  require Logger
  alias ExIrc.Client, as: IrcClient
  alias Hal.Dispatcher, as: Dispatcher
  alias Hal.Shepherd, as: Herd
  alias Hal.Keeper, as: Keeper
  alias Hal.Plugin.Url, as: Url

  defmodule Infos do
    defstruct msg: "",
      from: nil,
      host: nil,
      chan: [],
      uid: nil,
      pid: nil,
      answers: []
  end

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
    Logger.debug("[NEW] IrcHandler #{inspect self()}")
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

  def handle_info({:answer, _uid, nil}, state) do
    {:noreply, state}
  end

  def handle_info({:answer, uid, answers}, state) do
    case :ets.lookup(state.uids, uid) do
      [] -> :ok
      [{_uid, infos}] ->
        infos = %Infos{infos | answers: answers}
        answer_back(infos, state)
        :ets.delete(state.uids, uid)
    end
    {:noreply, state}
  end

  def handle_info({:connected, server, port}, state) do
    Logger.info("connecting to #{server}:#{port}")
    IrcClient.logon state.client, state.pass, state.nick, state.user, state.name
    {:noreply, state}
  end

  def handle_info(:disconnected, state) do
    throw("[ERR] Disconnected from #{state.host}")
    {:noreply, state}
  end

  # ExIrc.client.quit state.client, "I live, I die. I LIVE AGAIN!"
  def handle_info(:logged_in, state) do
    chans = state.chans |> Enum.join(", ")
    Logger.info("[#{state.host}] joining channels: #{chans}")
    Enum.each(state.chans, fn(chan) ->
      IrcClient.join state.client, chan
    end)
    {:noreply, state}
  end

  def handle_info({:joined, chan, from}, state) do
    infos = %Infos{msg: ".joined", from: from.nick, host: state.host, chan: chan}
    generic_received(infos, state)
    {:noreply, state}
  end

  def handle_info({:mentioned, _msg, _from, _chan}, state) do
    # do something when somebody mention us?
    {:noreply, state}
  end

  def handle_info({:received, msg, from}, state) do
    infos = %Infos{msg: msg, from: from.nick, host: state.host, chan: nil}
    generic_received(infos, state)
    {:noreply, state}
  end

  def handle_info({:received, msg, from, chan}, state) do
    infos = %Infos{msg: msg, from: from.nick, host: state.host, chan: chan}
    generic_received(infos, state)
    {:noreply, state}
  end

  def handle_info({:'ETS-TRANSFER', table_id, owner, module}, state) do
    Logger.debug("[ETS] #{inspect table_id} from #{inspect module} #{inspect owner}")
    state = %{state | uids: table_id}
    {:noreply, state}
  end

  def handle_info(msg, state) do
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
  defp give_me_an_id(infos) do
    time_seed = UUID.uuid1()
    data_seed = "#{infos.msg}#{infos.from}#{infos.host}#{infos.chan}"
    UUID.uuid5(time_seed, data_seed, :hex)
  end

  defp generic_received(infos, state) do
    case String.at(infos.msg, 0) do
      "." ->
        infos = generate_request(infos, state)
        [dispatcher_pid] = Herd.launch(:hal_shepherd, [Dispatcher], __MODULE__)
        Dispatcher.command(dispatcher_pid, infos)
      _ ->
        urls = Regex.scan(~r/https?:\/\/[^\s]+/, infos.msg) |> List.flatten
        case urls do
          [] ->
            nil
          _ ->
            infos = generate_request(infos, state)
            [url_pid] = Herd.launch(:hal_shepherd, [Url], __MODULE__)
            Url.preview(url_pid, urls, infos)
        end
    end
  end

  defp generate_request(infos, state) do
    uid = give_me_an_id(infos)
    infos = %{infos | uid: uid, pid: self()}
    true = :ets.insert(state.uids, {uid, infos})
    infos
  end

  defp answer_back(infos, state) do
    Enum.each(infos.answers, fn(answer) ->
      # take private_msg into account
      case infos.chan do
        nil -> IrcClient.msg state.client, :privmsg, infos.from, answer
        _   -> IrcClient.msg state.client, :privmsg, infos.chan, answer
      end
    end)
  end

end
