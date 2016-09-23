defmodule Hal.IrcSupervisor do
  @moduledoc """
  Supervise the various connection handler (IRC) with a simple_one_for_one
  strategy.
  """

  use Supervisor

  def start_link(args, opts \\ []) do
    Supervisor.start_link(__MODULE__, args, opts)
  end

  def init(args) do
    IO.puts "[NEW] IrcSupervisor #{inspect self()}"
    children = [
      worker(Hal.IrcHandler, [args, []])
    ]
    supervise(children, strategy: :one_for_one)
  end

end
