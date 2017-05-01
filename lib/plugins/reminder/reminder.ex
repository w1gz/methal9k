defmodule Hal.Plugin.Reminder do
  @moduledoc """
  Leave messages/reminder for a disconnected contact
  """

  use GenServer
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

  `req` is a couple {uid, frompid}. `uid` is the unique identifier for this
  request. Whereas `frompid` is the process for which the answer will be sent.

  `infos` is a 3-tuple {msg, from, chan}. `msg` initial and complete message
  (include the command).  `from` the person who initiated the reminder.  `chan`
  the channel on which this happened.
  """
  def set(pid, reminder, req, infos) do
    GenServer.cast(pid, {:set, reminder, req, infos})
  end

  @doc """
  Retrieve a reminder for a specific person in the appropriate channel.

  `pid` the pid of the GenServer that will be called.

  `req` is a couple {uid, frompid}. `uid` is the unique identifier for this
  request. Whereas `frompid` is the process for which the answer will be sent.

  `infos` is a 3-tuple {msg, from, chan}. `msg` initial and complete message
  (include the command).  `from` the person who initiated the reminder.  `chan`
  the channel on which this happened.
  """
  def get(pid, req, infos) do
    GenServer.cast(pid, {:get, req, infos})
  end

  # Server callbacks
  def init(args) do
    IO.puts("[NEW] PluginReminder #{inspect self()}")
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

  def handle_cast({:set, reminder, req, infos}, state) do
    # deconstruct our arguments
    {to, memo} = reminder
    {uid, frompid} = req
    {_, from, host, chan} = infos
    time = Timex.now

    # insert only if it does not exist yet
    query = fn ->
      case :mnesia.match_object({Reminder, to, host, chan, memo, from, :_}) do
        [] -> :mnesia.write({Reminder, to, host, chan, memo, from, time})
        something when is_list(something) -> nil # reminder already set
      end
    end

    # choose the appropriate answer given the mnesia transaction
    answer = case :mnesia.transaction(query) do
               {:atomic, :ok} -> "Reminder for #{to} is registered."
               {:atomic, nil} -> "Reminder already set."
             end

    Tool.terminate(self(), frompid, uid, [answer])
    {:noreply, state}
  end

  def handle_cast({:get, req, infos}, state) do
    {uid, frompid} = req
    {_, join_user, host, chan} = infos
    reminders_query = fn ->
      reminder = {Reminder, join_user, host, chan, :'$1', :'$2', :'$3'}
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
                    "#{from} to #{join_user}: #{memo} (#{time})"
                  end)
              end

    Tool.terminate(self(), frompid, uid, answers)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    IO.puts("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

end
