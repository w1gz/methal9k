defmodule Hal.PluginReminderKeeper do
  use GenServer

  # Client API
  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def give_me_your_table(pid) do
    GenServer.call(pid, :give_your_table)
  end


  # Server callbacks
  def init(_state) do
    reminders = :ets.new(:reminders, [{:heir, self(), nil}])
    new_state = %{reminders: reminders}
    {:ok, new_state}
  end

  def handle_call(:give_your_table, {frompid,_}, state) do
    reminders = state[:reminders]
    :ets.give_away(reminders, frompid, nil)
    {:reply, reminders, state}
  end

  def handle_info({:'ETS-TRANSFER', table_id, _old_owner, _data}, _state) do
    new_state = %{reminders: table_id}
    {:noreply, new_state}
  end

end
