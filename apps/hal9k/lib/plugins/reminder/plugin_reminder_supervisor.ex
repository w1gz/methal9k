defmodule Hal.PluginReminderSupervisor do
  use Supervisor

  def start_link(type, args) do
    opts = [name: :hal_plugin_reminder_supervisor]
    Supervisor.start_link(__MODULE__, [type, args], opts)
  end

  def init(args) do
    children = [
      worker(Hal.PluginReminderKeeper,
             [args, [restart: :permanent, name: :hal_plugin_reminder_keeper]]),
      worker(Hal.PluginReminder,
             [args, [restart: :permanent, name: :hal_plugin_reminder]])
    ]

    supervise(children, strategy: :one_for_one)
  end

end
