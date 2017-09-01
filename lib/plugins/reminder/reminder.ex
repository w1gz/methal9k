defmodule Hal.Plugin.Reminder do
  @moduledoc """
  Leave messages/reminder for a disconnected contact
  """

  use GenServer
  require Logger
  alias Hal.Tool, as: Tool

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def usage(pid) do
    GenServer.call(pid, :usage)
  end

  @doc """
  Sets a reminder for a person in a specific channel. This doesn't work on
  private messages.

  `user` is the person that needs to be reminded.
  `memo` message to register for the `user`.

  `pid` the pid of the GenServer that will be called.
  """
  def set(pid, reminder, infos) do
    GenServer.cast(pid, {:set, reminder, infos})
  end

  @doc """
  Retrieve a reminder for a specific person in the appropriate channel.

  `pid` the pid of the GenServer that will be called.
  """
  def get(pid, infos) do
    GenServer.cast(pid, {:get, infos})
  end

  # Server callbacks
  def init(args) do
    Logger.debug("[NEW] PluginReminder #{inspect self()}")
    :mnesia.create_table(Reminder, [
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
    answer = ".remind <someone> <msg> as soon as he /join this channel"
    {:reply, answer, state}
  end

  def handle_cast({:set, {to, memo} = _reminder, infos}, state) do
    {:ok, time} = Timex.format(Timex.now(), "%D, %R UTC", :strftime)

    # insert only if it does not exist yet
    query = fn ->
      case :mnesia.match_object({Reminder, to, infos.host, infos.chan, memo,
                                  infos.from, :_}) do
        [] ->
          rem = {Reminder, to, infos.host, infos.chan, memo, infos.from, time}
          :mnesia.write(rem)
        something when is_list(something) ->
          nil # reminder already set end end
      end
    end

    # choose the appropriate answer given the mnesia transaction
    answers = case :mnesia.transaction(query) do
               {:atomic, :ok} -> "Reminder for #{to} is registered."
               {:atomic, nil} -> "Reminder already set."
             end

    Tool.terminate(infos.pid, infos.uid, answers)
    {:noreply, state}
  end

  def handle_cast({:get, infos}, state) do
    # {_, join_user, host, chan} = infos
    reminders_query = fn ->
      reminder = {Reminder, infos.from, infos.host, infos.chan, :'$1', :'$2', :'$3'}
      case :mnesia.match_object(reminder) do
        [] -> []
        something when is_list(something) ->
          Enum.each(something, &(:mnesia.delete_object(&1)))
          something
      end
    end

    # parse & send what we matched
    answers = case :mnesia.transaction(reminders_query) do
                {:atomic, []} -> nil
                {:atomic, results} ->
                  Enum.map(results, fn(res) ->
                    {_reminder, _to, _host, _chan, memo, from, time} = res
                    "#{from} to #{infos.from}: #{memo} (#{time})"
                  end)
              end

    Tool.terminate(infos.pid, infos.uid, answers)
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
