defmodule Hal.HandlerSupervisor do
  @moduledoc """
  Supervise the various connection handler (IRC) with a one_for_one strategy.
  """

  use Supervisor

  def start_link(_type, args, _opts \\ []) do
    Supervisor.start_link(__MODULE__, args, [name: :hal_handler_supervisor])
  end

  def init(args) do
    children = [
      worker(Hal.ConnectionHandlerKeeper,
        [args, [restart: :permanent, name: :hal_connection_handler_keeper]]),
      worker(Hal.ConnectionHandler,
        [args, [restart: :permanent, name: :hal_connection_handler]])
    ]

    supervise(children, strategy: :one_for_one)
  end

end
