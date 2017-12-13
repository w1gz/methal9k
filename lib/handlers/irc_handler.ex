defmodule Hal.IrcHandler do
  @moduledoc """
  The module will maintain a link to the ExIrc library in order to intercept and
  send message to IRC.
  """

  use GenServer
  require Logger
  alias ExIrc.Client, as: IrcClient
  alias Hal.CommonHandler, as: Handler

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

    state = %{irc_credz: args, buffer: []}
    {:ok, state}
  end

  def handle_call({:get_state}, _frompid, state) do
    {:reply, state, state}
  end

  def handle_call({:get_users, chan}, _frompid, state) do
    irc = state[:irc_credz]
    res = {irc.nick, IrcClient.channel_users(irc.client, chan)}
    {:reply, res, state}
  end

  def handle_call({:has_user, chan, user}, _frompid, state) do
    irc = state[:irc_credz]
    status = IrcClient.channel_has_user?(irc.client, chan, user)
    {:reply, status, state}
  end

  def handle_info({:answer, infos, type}, state) do
    answer_back(infos, state, type)
    {:noreply, state}
  end

  def handle_info({:connected, server, port}, state) do
    irc = state[:irc_credz]
    Logger.info("Registering #{irc.user} (#{irc.nick}) to #{server}:#{port}")
    IrcClient.logon irc.client, irc.pass, irc.nick, irc.user, irc.name
    {:noreply, state}
  end

  def handle_info(:disconnected, state) do
    irc = state[:irc_credz]
    throw("[ERR] Disconnected from #{irc.host}")
    {:noreply, state}
  end

  # ExIrc.client.quit state[:irc_credz].client, "I live, I die. I LIVE AGAIN!"
  def handle_info(:logged_in, state) do
    irc = state[:irc_credz]
    chans = irc.chans |> Enum.join(", ")
    Logger.info("[#{irc.host}] joining channels: #{chans}")
    Enum.each(irc.chans, fn(chan) ->
      IrcClient.join irc.client, chan
    end)
    {:noreply, state}
  end

  def handle_info({:joined, chan, from}, state) do
    irc = state[:irc_credz]
    infos = %Handler.Infos{msg: ".joined", from: from.nick, host: irc.host, chan: chan, pid: self()}
    updated_buffer = update_circular_buffer(infos, state)
    state = Map.put(state, :buffer, updated_buffer)
    {:noreply, state}
  end

  def handle_info({:mentioned, _msg, _from, _chan}, state) do
    # do something when somebody mention us?
    {:noreply, state}
  end

  def handle_info({:received, msg, from}, state) do
    irc = state[:irc_credz]
    infos = %Handler.Infos{msg: msg, from: from.nick, host: irc.host, chan: nil, pid: self()}
    updated_buffer = update_circular_buffer(infos, state)
    state = Map.put(state, :buffer, updated_buffer)
    {:noreply, state}
  end

  def handle_info({:received, msg, from, chan}, state) do
    irc = state[:irc_credz]
    infos = %Handler.Infos{msg: msg, from: from.nick, host: irc.host, chan: chan, pid: self()}
    updated_buffer = update_circular_buffer(infos, state)
    state = Map.put(state, :buffer, updated_buffer)
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

  defp check_sed(infos, state) do
    buffer = state[:buffer]
    irc_credz = state[:irc_credz]
    sed = Regex.named_captures(~r{^s/(?<left>.*?)/(?<right>.*?)(/g|/)?$}, infos.msg)
    case sed do
      nil ->
        limit_per_chan = 100
        limit_for_all_chans = limit_per_chan * max(1, length(irc_credz.chans))
        Logger.debug(Enum.join(["Circular buffer ",
                                "#{infos.chan} at #{length(buffer)}/#{limit_per_chan} ",
                                "(max #{limit_for_all_chans} with #{length(irc_credz.chans)} chan(s))"]))
        new_buffer = List.insert_at(buffer, 0, infos)
        if length(new_buffer) > limit_per_chan do List.delete_at(new_buffer, -1) else new_buffer end
      _ ->
        match = look_for_substitute(infos, buffer)
        infos = substitute(match, sed["left"], sed["right"], infos)
        answer_back(infos, state, :msg)
        buffer
    end
  end

  defp substitute(nil, _left, _right, infos) do
    Logger.debug("Can't find something to sed")
    %Handler.Infos{infos | answers: [nil]}
  end

  defp substitute(match, left, right, infos) do
    Logger.debug("Replacing '#{left}' by '#{right}' in '#{match.msg}'")
    seded = String.replace(match.msg, left, right)
    answer = "#{match.from} meant to say '#{seded}'"
    %Handler.Infos{infos | answers: [answer]}
  end

  defp look_for_substitute(infos, buffer) do
    buffer
    |> Enum.filter(fn(i) ->
      i.from == infos.from and
      i.chan == infos.chan and
      i.host == infos.host
    end)
    |> List.first
  end

  defp answer_back(infos, state, type) do
    infos.answers
    |> Enum.filter(fn(x) -> x != nil end)
    |> Enum.each(fn(answer) ->
      msg = answer |> String.trim |> String.split("\n") |> Enum.join(" - ")
      irc = state[:irc_credz]
      type = if infos.chan do type else :privmsg end # check if this is a private msg
      case type do
        :msg     -> IrcClient.msg(irc.client, :privmsg, infos.chan, msg)
        :privmsg -> IrcClient.msg(irc.client, :privmsg, infos.from, msg)
        :notice  -> IrcClient.msg(irc.client, :notice, infos.chan, msg)
        :ctcp    -> IrcClient.msg(irc.client, :ctcp, infos.chan, msg)
        :me      -> IrcClient.me(irc.client, infos.chan, msg)
      end
    end)
  end

  defp update_circular_buffer(infos, state) do
    case Handler.check_command(infos) do
      :ok -> state[:buffer]
      nil ->
        Handler.check_url(infos)         # do we have an http link to fetch ?
        check_sed(infos, state)  # circular buffer for the sed-like feature
    end
  end

end
