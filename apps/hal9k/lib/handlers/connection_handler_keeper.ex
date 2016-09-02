defmodule Hal.ConnectionHandlerKeeper do
  @moduledoc """
  Keep & protect the state of a connection handler
  """

  use GenServer

  # Client API
  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  @doc """
  Retrieve the ETS table stored in its internal state and give it to the first
  person who ask for it.

  `pid` the pid of the GenServer that will be called

  ##Example
  ```Elixir
  iex> Hal.ConnectionHandlerKeeper.give_me_your_table(pid)
  ```
  """
  def give_me_your_table(pid) do
    GenServer.call(pid, :give_your_table)
  end


  # Server callbacks
  def init(_state) do
    uids = :ets.new(:uids, [{:heir, self(), nil}])
    new_state = %{uids: uids}
    {:ok, new_state}
  end

  def handle_call(:give_your_table, {frompid,_}, state) do
    uids = state[:uids]
    :ets.give_away(uids, frompid, nil)
    {:reply, uids, state}
  end

  def handle_info({:'ETS-TRANSFER', table_id, _old_owner, _data}, _state) do
    new_state = %{uids: table_id}
    {:noreply, new_state}
  end

  def terminate(reason, _state) do
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

end
