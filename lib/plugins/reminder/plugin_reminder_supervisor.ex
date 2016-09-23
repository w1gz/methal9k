defmodule Hal.PluginReminderSupervisor do
  @moduledoc """
  Supervise the reminder plugin using a one_for_one strategy.
  """

  use Supervisor

  def start_link(args, opts \\ []) do
    Supervisor.start_link(__MODULE__, args, opts)
  end

  def init(_args) do
    IO.puts("[NEW] PluginReminderSupervisor #{inspect self()}")
    children = [
      worker(Hal.PluginReminder, [[], [name: :hal_plugin_reminder]])
    ]
    supervise(children, strategy: :one_for_one)
  end

end
