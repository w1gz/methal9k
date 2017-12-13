defmodule Hal.PluginSupervisor do

  @moduledoc """
  Supervise the various plugins with a simple_one_for_one strategy.
  """

  use Supervisor
  require Logger
  alias Hal.Tool, as: Tool

  def start_link(args, opts \\ []) do
    Supervisor.start_link(__MODULE__, args, opts)
  end

  def init(_args) do
    Logger.debug("[NEW] PluginsSupervisor #{inspect self()}")

    children = [
      :poolboy.child_spec(:p_plugin_quote, Tool.poolboy_conf(Hal.Plugin.Quote, 10, 5)),
      :poolboy.child_spec(:p_plugin_bouncer, Tool.poolboy_conf(Hal.Plugin.Bouncer, 10, 5)),
      :poolboy.child_spec(:p_plugin_time, Tool.poolboy_conf(Hal.Plugin.Time, 10, 5)),
      :poolboy.child_spec(:p_plugin_web, Tool.poolboy_conf(Hal.Plugin.Web, 10, 5)),
      :poolboy.child_spec(:p_plugin_weather, Tool.poolboy_conf(Hal.Plugin.Weather, 10, 5))
    ]
    supervise(children, strategy: :one_for_one)
  end

end
