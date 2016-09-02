defmodule Core.PluginSupervisor do
  @moduledoc """
  Supervise all the core plugins with a one_for_one strategy.
  """

  use Supervisor

  def start_link(type, args, _opts \\ []) do
    opts = [name: :core_plugin_supervisor]
    Supervisor.start_link(__MODULE__, [type, args], opts)
  end

  def init(args) do
    children = [
      worker(Core.PluginBrain, [args,
                                [restart: :permanent,
                                 name: :core_plugin_brain]]),
      worker(Core.PluginWeather, [args,
                                  [restart: :permanent,
                                   name: :core_plugin_weather]]),
      worker(Core.PluginTime, [args,
                               [restart: :permanent,
                                name: :core_plugin_time]]),
      supervisor(Core.PluginReminderSupervisor, args,
        restart: :permanent)
    ]

    supervise(children, _opts = [strategy: :one_for_one])
  end

end
