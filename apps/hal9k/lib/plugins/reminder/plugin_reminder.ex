defmodule Hal.PluginReminder do
  use GenServer

  # Client API
  def start_link(args, opts \\ []) do
    IO.puts("New PluginReminder")
    GenServer.start_link(__MODULE__, args, opts)
  end

  def set_reminder(pid, reminder, opts, req) do
    GenServer.call(pid, {:set_reminder, reminder, opts, req})
  end

  def remind_someone(pid, infos, req) do # called when a user join a subscribe chan
    GenServer.call(pid, {:remind_someone, infos, req})
  end


  # Server callbacks
  def init(_state) do
    reminders = Hal.PluginReminderKeeper.give_me_your_table(:hal_plugin_reminder_keeper)
    new_state = %{reminders: reminders}
    {:ok, new_state}
  end

  def handle_call({:set_reminder, _to_remind={user, memo}, _opts={_msg,from,chan}, _req={uid,_}}, _frompid, state) do
    rem = state[:reminders]
    reminder = {from, chan, memo}

    # construct a new reminder
    case :ets.lookup(rem, user) do
      [] ->
        true = :ets.insert_new(rem, {user, [reminder]})
      [{_user, reminders}] ->
        reminders = List.insert_at(reminders, -1, reminder)
        true = :ets.insert(rem, {user, reminders})
    end

    answer = "Reminder for #{user} is now registered."
    Hal.ConnectionHandler.answer(:hal_connection_handler, {uid, [answer]})
    {:reply, :ok, state}
  end

  def handle_call({:remind_someone, _infos={chan, user}, _req={uid,_msg}},_frompid, state) do
    reminders_state = state[:reminders]
    rem_lookup = :ets.lookup(reminders_state, user)
    case rem_lookup do
      [] -> :ok
      [{lookup_user, reminders}] ->
        memos = get_reminders(reminders, lookup_user, user, chan)

        # send the answers
        answers = Enum.map(memos, fn({atom, value}) ->
          if atom == :ok do value end
        end)
        Hal.ConnectionHandler.answer(:hal_connection_handler, {uid, answers})

        # Remove the delivered memos from the list
        memo_left = Enum.filter(memos, fn({atom, _value}) ->
          atom != :ok and atom != nil
        end)

        # Update our ETS table
        case memo_left do
          [] -> :ets.delete(reminders_state, user)
          [{_,_}] -> :ets.insert(rem_lookup, {lookup_user, memo_left})
        end
    end
    {:reply, :ok, state}
  end

  def terminate(reason, _state) do
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end


  # Internal functions
  defp get_reminders(reminders, lookup_user, user, chan) do
    Enum.map(reminders, fn(reminder={r_from, r_chan, r_memo}) ->
      if r_chan == chan and lookup_user == user do
        answer = "memo from #{r_from} to #{user}: #{r_memo}"
        {:ok, answer}
      else # r_memo
        {:ko, reminder}
      end end)
  end

end
