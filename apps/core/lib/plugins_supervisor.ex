defmodule Core.PluginSupervisor do
  use Supervisor

  def start_link(type, args, _opts \\ []) do
    Supervisor.start_link(__MODULE__, {type, args}, [name: :core_plugin_supervisor])
  end

  def init({_type, args}) do
    children = [
      worker(Core.PluginBrain, [args, [restart: :permanent, name: :core_plugin_brain]]),
      worker(Core.PluginWeather, [args, [restart: :permanent, name: :core_plugin_weather]])
    ]

    supervise(children, _opts=[strategy: :one_for_one])
  end

end
