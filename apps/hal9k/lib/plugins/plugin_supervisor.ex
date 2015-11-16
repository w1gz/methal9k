defmodule Hal.PluginSupervisor do
  use Supervisor

  def start_link(type, args) do
    Supervisor.start_link(__MODULE__, [type, args], [name: :hal_plugin_supervisor])
  end

  def init(args) do
    children = [
      supervisor(Hal.PluginReminderSupervisor, args, restart: :permanent)
    ]

    supervise(children, strategy: :one_for_one)
  end

end
