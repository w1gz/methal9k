defmodule Hal.PluginReminder do
  @moduledoc """
  Leave messages/reminder for a disconnected contact
  """

  use GenServer
  alias Hal.Keeper, as: Keeper

  # Client API
  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
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
    GenServer.call(pid, {:set_reminder, reminder, req, infos})
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
    GenServer.call(pid, {:get_reminder, req, infos})
  end

  @doc """
  Helper for manually purge expired reminders. Note that expired reminders will
  still be sent to their respective channels upon removal.

  `pid` the pid of the GenServer that will be called.

  `timeshift` is the limit at which we consider a reminder "too old".

  The available `unit` for the timeshift are the following:
  - :seconds
  - :minutes
  - :hours
  - :days
  """
  def purge_expired(pid, timeshift, unit) do
    GenServer.call(pid, {:purge_expired, timeshift, unit})
  end


  # Server callbacks
  def init(_args) do
    IO.puts("[NEW] PluginReminder #{inspect self()}")
    reminders = case Keeper.give_me_your_table(:hal_keeper, __MODULE__) do
                  true -> nil   # we will receive this by ETS-TRANSFER later on
                  _ -> hal_pid = Process.whereis(:hal_keeper)
                  :ets.new(:reminders, [:duplicate_bag,
                                        :private,
                                        {:heir, hal_pid, __MODULE__}])
                end
    state = %{reminders: reminders}
    {:ok, state}
  end

  def handle_call({:set_reminder, reminder, req, infos}, _, state) do
    {to, memo} = reminder
    {uid, frompid} = req
    {_, from, chan} = infos
    reminders = state[:reminders]
    current_time = Timex.now
    true = :ets.insert(reminders, {chan, from, to, memo, current_time})

    # construct and send the answer
    time_str = "%F - %T UTC"
    {:ok, ttl} = Timex.format(shift_time(current_time), time_str, :strftime)
    answer = "Reminder for #{to} is registered and will autodestroy on #{ttl}."
    send frompid, {:answer, {uid, [answer]}}
    {:reply, :ok, state}
  end

  def handle_call({:get_reminder, {uid, frompid}, {_, from, chan}}, _, state) do
    reminders = state[:reminders]
    matched = :ets.match(reminders, {chan, :'$1', from, :'$2', :'$3'})
    send_answers(matched, from, uid, frompid)
    true = :ets.match_delete(reminders, {chan, :'$1', from, :'$2', :'$3'})
    {:reply, :ok, state}
  end

  def handle_call({:purge_expired, timeshift, unit}, frompid, state) do
    purge_expired_reminders(state[:reminders], timeshift, unit, frompid)
    {:reply, :ok, state}
  end

  def handle_info({:'ETS-TRANSFER', table_id, owner, module}, state) do
    IO.puts("[ETS] #{inspect table_id} from #{inspect module} #{inspect owner}")
    state = %{state | reminders: table_id}
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
  defp purge_expired_reminders(reminders, timeshift, unit, frompid) do
    # fetch the expired memo
    current_time = Timex.now
    matched = :ets.match(reminders, {:'$1', :'$2', :'$3', :'$4', :'$5'})
    Enum.each(matched, fn(reminder = [chan, from, to, memo, time]) ->
      if Timex.before?(shift_time(time, unit, timeshift), current_time) do
        answer = "[EXPIRED] " <> generic_answer(from, to, memo, time)
        IO.puts(answer)
        send frompid, {:answer, {chan, to, [answer]}}
        true = :ets.match_delete(reminders, reminder)
      end
    end)
  end

  defp send_answers(matched, user, uid, frompid) do
    Enum.each(matched, fn([from, memo, time]) ->
      answer = generic_answer(from, user, memo, time)
      send frompid, {:answer, {uid, [answer]}}
    end)
  end

  defp generic_answer(r_from, user, r_memo, time) do
    {:ok, ttl} = Timex.format(time, "%F - %T UTC", :strftime)
    _answer = "\{#{ttl}\} #{r_from} to #{user}: #{r_memo}"
  end

  defp shift_time(time, unit \\ :days, timeshift \\ 7) do
    case unit do
      :days    -> Timex.shift(time, days: timeshift)
      :hours   -> Timex.shift(time, hours: timeshift)
      :minutes -> Timex.shift(time, minutes: timeshift)
      :seconds -> Timex.shift(time, seconds: timeshift)
    end
  end

end
