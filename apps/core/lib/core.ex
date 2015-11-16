defmodule Core do
  use Application

  def start(type, args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Core.PluginSupervisor, [type, args], restart: :permanent)
    ]

    opts = [strategy: :one_for_one, name: :core_supervisor]
    Supervisor.start_link(children, opts)
  end
end
