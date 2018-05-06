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
      :poolboy.child_spec(:p_plugin_quote, Tool.poolboy_conf(Hal.Plugin.Quote)),
      :poolboy.child_spec(:p_plugin_bouncer, Tool.poolboy_conf(Hal.Plugin.Bouncer)),
      :poolboy.child_spec(:p_plugin_time, Tool.poolboy_conf(Hal.Plugin.Time)),
      :poolboy.child_spec(:p_plugin_web, Tool.poolboy_conf(Hal.Plugin.Web)),
      :poolboy.child_spec(:p_plugin_weather, Tool.poolboy_conf(Hal.Plugin.Weather))
    ]
    supervise(children, strategy: :one_for_one)
  end

end
