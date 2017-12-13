defmodule Hal.SlackSupervisor do
  @moduledoc """
  Supervise the various connection handler (Slack) with a simple_one_for_one
  strategy.
  """

  use Supervisor
  require Logger

  def start_link(args, opts \\ []) do
    Supervisor.start_link(__MODULE__, args, opts)
  end

  def init(slack_conf) do
    Logger.debug("[NEW] SlackSupervisor #{inspect self()}")
    children = Enum.map(slack_conf, fn(conf) ->
      token = conf[:token]
      host = conf[:host]
      worker(Slack.Bot, [Hal.SlackHandler, [], token], [id: host])
    end)
    supervise(children, strategy: :one_for_one)
  end

end
