defmodule Hal.IrcHandler do
  @moduledoc """
  The module will maintain a link to the ExIrc library in order to intercept and
  send message to IRC.
  """

  use GenServer
  require Logger
  alias ExIrc.Client, as: IrcClient
  alias Hal.Dispatcher, as: Dispatcher
  alias Hal.Plugin.Url, as: Url

  defmodule Infos do
    defstruct msg: "",
      from: nil,
      host: nil,
      chan: [],
      pid: nil,
      answers: []
  end

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def get_state(pid) do
    GenServer.call(pid, {:get_state})
  end

  def get_users(pid, chan) do
    GenServer.call(pid, {:get_users, chan})
  end

  def has_user(pid, chan, user) do
    GenServer.call(pid, {:has_user, chan, user})
  end

  def init(args) do
    Logger.debug("[NEW] IrcHandler #{inspect self()}")
    case IrcClient.is_logged_on? args.client do
      true ->
        IrcClient.add_handler args.client, self()
        send self(), :logged_in
      _ ->
        Logger.debug("Connecting to #{args.host}:#{args.port}")
        IrcClient.add_handler args.client, self()
        IrcClient.connect_ssl! args.client, args.host, args.port
    end
    {:ok, args}
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

  def handle_info({:answer, infos}, state) do
    answer_back(infos, state)
    {:noreply, state}
  end

  def handle_info({:connected, server, port}, state) do
    Logger.info("Registering #{state.user} (#{state.nick}) to #{server}:#{port}")
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
    infos = %Infos{msg: ".joined", from: from.nick, host: state.host, chan: chan, pid: self()}
    generic_received(infos)
    {:noreply, state}
  end

  def handle_info({:mentioned, _msg, _from, _chan}, state) do
    # do something when somebody mention us?
    {:noreply, state}
  end

  def handle_info({:received, msg, from}, state) do
    infos = %Infos{msg: msg, from: from.nick, host: state.host, chan: nil, pid: self()}
    generic_received(infos)
    {:noreply, state}
  end

  def handle_info({:received, msg, from, chan}, state) do
    infos = %Infos{msg: msg, from: from.nick, host: state.host, chan: chan, pid: self()}
    generic_received(infos)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.debug("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  defp generic_received(infos) do
    case String.at(infos.msg, 0) do
      "." ->
        :poolboy.transaction(Dispatcher, fn(pid) ->
          Dispatcher.command(pid, infos)
        end)
      _ ->
        urls = Regex.scan(~r/https?:\/\/[^\s]+/, infos.msg) |> List.flatten
        case urls do
          [] ->
            nil
          _ ->
            :poolboy.transaction(Url, fn(pid) ->
              Url.preview(pid, urls, infos)
            end)
        end
    end
  end

  defp answer_back(infos, state) do
    infos.answers
    |> Enum.filter(fn(x) -> x != nil end)
    |> Enum.each(fn(answer) ->
      msg = answer |> String.trim |> String.split("\n") |> Enum.join(" - ")
      # take private_msg into account
      case infos.chan do
        nil -> IrcClient.msg state.client, :privmsg, infos.from, msg
        _   -> IrcClient.msg state.client, :privmsg, infos.chan, msg
      end
    end)
  end

end
