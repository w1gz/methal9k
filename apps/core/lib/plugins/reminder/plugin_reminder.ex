defmodule Core.PluginReminder do
  use GenServer

  # Client API
  def start_link(args, opts \\ []) do
    IO.puts("[INFO] New PluginReminder")
    GenServer.start_link(__MODULE__, args, opts)
  end

  def set_reminder(pid, reminder, req, infos) do
    GenServer.call(pid, {:set_reminder, reminder, req, infos})
  end

  def remind_someone(pid, req, infos) do
    GenServer.call(pid, {:remind_someone, req, infos})
  end

  def purge_expired(pid, timeshift, unit) do
    GenServer.cast(pid, {:purge_expired, timeshift, unit})
  end

  # Server callbacks
  def init(_state) do
    reminders = Core.PluginReminderKeeper.give_me_your_table(:core_plugin_reminder_keeper)
    new_state = %{reminders: reminders}
    {:ok, new_state}
  end

  def handle_call({:set_reminder, _to_remind={to, memo}, _req={uid,frompid}, _infos={_msg,from,chan}}, _frompid, state) do
    reminders = state[:reminders]
    current_time = Timex.DateTime.now
    true = :ets.insert(reminders, {chan, from, to, memo, current_time})

    # construct and send the answer
    {:ok, ttl} = Timex.format(shift_time(current_time), "%F - %T UTC", :strftime)
    answers = "Reminder for #{to} is registered and will autodestroy on #{ttl}."
    send frompid, {:answer, {uid, [answers]}}

    {:reply, :ok, state}
  end

  def handle_call({:remind_someone, _req={uid,frompid}, _infos={_msg,from,chan}}, _frompid, state) do
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

  def terminate(reason, _state) do
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end


  # Internal functions
  defp purge_expired_reminders(reminders, unit, timeshift, frompid) do
    # fetch the expired memo
    current_time = Timex.DateTime.now
    matched = :ets.match(reminders, {:'$1', :'$2', :'$3', :'$4', :'$5'})
    Enum.each(matched, fn(reminder=[chan, from, to, memo, time]) ->
      if Timex.before?(shift_time(time, unit, timeshift), current_time) == true do
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
