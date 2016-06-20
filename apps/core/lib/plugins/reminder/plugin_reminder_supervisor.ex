defmodule Core.PluginReminderSupervisor do
  use Supervisor

  def start_link(type, args, _opts \\ []) do
    opts = [name: :core_plugin_reminder_supervisor]
    Supervisor.start_link(__MODULE__, [type, args], opts)
  end

  def init(args) do
    children = [
      worker(Core.PluginReminderKeeper,
             [args, [restart: :permanent, name: :core_plugin_reminder_keeper]]),
      worker(Core.PluginReminder,
             [args, [restart: :permanent, name: :core_plugin_reminder]])
    ]

    supervise(children, strategy: :one_for_one)
  end

end
