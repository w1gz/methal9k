defmodule Hal.Shepherd do
  @moduledoc """
  Spawn and Herd the dynamically spawned processes.
  """

  use GenServer
  alias Hal.Keeper, as: Keeper

  # Client API
  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end


  @doc """
  Return the list of pids.

  `pid` the pid of the GenServer that will be called.

  `modules` the type of process we want to create.

  `parent_module` the type of process that launch the request.

  `parent_pid` the process's pid that launch the request.
  """
  def launch(pid, modules, parent_module, parent_pid \\ nil) do
    GenServer.call(pid, {:launch, modules, {parent_module, parent_pid}})
  end

  @doc """
  Stop the processes given as argument.

  `pid` the pid of the GenServer that will be called.

  `modules` the modules we want to stop.
  """
  def stop(pid, modules) do
    GenServer.cast(pid, {:stop, modules})
  end


  # Server callbacks
  def init(_args) do
    IO.puts "[NEW] Shepherd #{inspect self()}"
    processes = case Keeper.give_me_your_table(:hal_keeper, __MODULE__) do
                  true -> nil   # we will receive this by ETS-TRANSFER later on
                  _ -> hal_pid = Process.whereis(:hal_keeper)
                  :ets.new(:processes, [:duplicate_bag,
                                        :protected,
                                        {:heir, hal_pid, __MODULE__}])
                end
    state = %{processes: processes}
    {:ok, state}
  end

  def handle_call({:launch, modules, parent}, _frompid, state) do
    module_pids = Enum.map(modules, fn(module) ->
      {:ok, module_pid} = module.start_link()
      true = :ets.insert_new(state.processes, {module_pid, module, parent})
      module_pid
    end)
    {:reply, module_pids, state}
  end

  def handle_cast({:stop, pids}, state) do
    Enum.each(pids, fn(pid) ->
      terminate_processes(pid, state)
    end)
    {:noreply, state}
  end

  def handle_info({:'ETS-TRANSFER', table_id, owner, module}, state) do
    IO.puts("[ETS] #{inspect table_id} from #{inspect module} #{inspect owner}")
    state = %{state | processes: table_id}
    {:noreply, state}
  end

  def terminate(reason, _state) do
    IO.puts("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  defp kill_process(pid, module) do
    Process.unlink(pid)
    # TODO Handle other behavior such as Supervisor?
    case GenServer.stop(pid) do
      :ok -> nil
      _ -> IO.puts("[ERR] Can't kill #{inspect module} #{inspect pid}")
    end
  end

  defp match_delete(module_pid, state) do
    # retrieve the module infos and delete its entry
    case :ets.match(state.processes, {module_pid, :'$1', :'$2'}) do
      [] -> {module_pid, module_pid}
      [first_match] ->
        true = :ets.match_delete(state.processes, {module_pid, :'$1', :'$2'})
        [module | parent] = first_match
        {module, hd(parent)}
    end
  end

  defp terminate_processes(module_pid, state) do
    case match_delete(module_pid, state) do
      {module, parent} ->
        kill_process(module_pid, module)
        case parent do          # do we need to go deeper?
          {p_module, nil} -> nil
          {p_module, p_pid} -> terminate_processes(p_pid, state)
        end
    end
  end

end
