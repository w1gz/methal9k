defmodule Hal.PluginSupervisor do
  @moduledoc """
  Supervise all the core plugins with a one_for_one strategy.
  """

  use Supervisor

  def start_link(args, opts \\ []) do
    Supervisor.start_link(__MODULE__, args, opts)
  end

  def init(_args) do
    IO.puts "[NEW] PluginSupervisor #{inspect self()}"
    children = [
      supervisor(Hal.PluginReminderSupervisor, [[], []])
    ]

    supervise(children, _opts = [strategy: :one_for_one])
  end

end
