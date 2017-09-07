defmodule Hal.Keeper do
  @moduledoc """
  Keep & protect an ETS table from an unstable GenServer
  """
  use GenServer
  require Logger

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def give_me_your_table(pid, module) do
    Logger.debug("[ETS] asking #{inspect pid} for the table of #{inspect module}")
    GenServer.call(pid, {:give_me_your_table, module})
  end

  def init(_args) do
    Logger.debug("[NEW] Keeper #{inspect self()}")
    state = Map.new()
    {:ok, state}
  end

  def handle_call({:give_me_your_table, module}, {frompid,_}, state) do
    backup = case state[module] do
               nil -> []
               [] -> []
               [h | _] -> :ets.give_away(h, frompid, nil)
             end
    {:reply, backup, state}
  end

  def handle_info({:'ETS-TRANSFER', table_id, owner, module}, state) do
    Logger.debug("[ETS] #{inspect table_id} from #{inspect module} #{inspect owner}")
    backups = case state[module] do
                       nil -> [table_id]
                       [] -> [table_id]
                       [l] -> [table_id | l]
                     end
    state = Map.put(state, module, backups)
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
