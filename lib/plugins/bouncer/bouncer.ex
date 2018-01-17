defmodule Hal.Plugin.Bouncer do
  @moduledoc """
  Leave messages for a disconnected contact
  """

  use GenServer
  require Logger
  alias Hal.CommonHandler, as: Handler

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def usage(pid) do
    GenServer.call(pid, :usage)
  end

  def set(pid, bouncer, infos) do
    GenServer.cast(pid, {:set, bouncer, infos})
  end

  def get(pid, infos) do
    GenServer.cast(pid, {:get, infos})
  end

  def init(args) do
    Logger.debug("[NEW] PluginBouncer #{inspect self()}")
    :mnesia.create_table(Bouncer, [
          attributes: [:to,
                       :host,
                       :chan,
                       :memo,
                       :from,
                       :time],
          type: :bag,
          disc_copies: [node()]])
    {:ok, args}
  end

  def handle_call(:usage, _frompid, state) do
    answer = ".bounce <someone> <msg>, send a <msg> as soon as they /join this channel (IRC only)"
    {:reply, answer, state}
  end

  def handle_cast({:set, {to, memo} = _bouncer, infos}, state) do
    {:ok, time} = Timex.format(Timex.now(), "%D, %R UTC", :strftime)

    # insert only if it does not exist yet
    query = fn ->
      case :mnesia.match_object({Bouncer, to, infos.host, infos.chan, memo,
                                 infos.from, :_}) do
        [] ->
          rem = {Bouncer, to, infos.host, infos.chan, memo, infos.from, time}
          :mnesia.write(rem)
        something when is_list(something) ->
          nil # bouncer already set end end
      end
    end

    # choose the appropriate answer given the mnesia transaction
    answer = case :mnesia.transaction(query) do
               {:atomic, :ok} -> "Bouncer for #{to} is registered."
               {:atomic, nil} -> "Bouncer already set."
             end
    infos = %Handler.Infos{infos | answers: [answer]}
    Handler.terminate(infos)
    {:noreply, state}
  end

  def handle_cast({:get, infos}, state) do
    bouncers_query = fn ->
      bouncer = {Bouncer, infos.from, infos.host, infos.chan, :'$1', :'$2', :'$3'}
      case :mnesia.match_object(bouncer) do
        [] -> []
        something when is_list(something) ->
          Enum.each(something, &(:mnesia.delete_object(&1)))
          something
      end
    end

    # parse & send what we matched
    answers = case :mnesia.transaction(bouncers_query) do
                {:atomic, []} -> [nil]
                {:atomic, results} ->
                  Enum.map(results, fn(res) ->
                    {_bouncer, _to, _host, _chan, memo, from, time} = res
                    "#{from} to #{infos.from}: #{memo} (#{time})"
                  end)
              end

    infos = %Handler.Infos{infos | answers: answers}
    Handler.terminate(infos)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.debug("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

end
