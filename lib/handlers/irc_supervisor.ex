defmodule Hal.IrcSupervisor do
  @moduledoc """
  Supervise the various connection handler (IRC) with a simple_one_for_one
  strategy.
  """

  use Supervisor
  require Logger
  alias Hal.State, as: State

  def start_link(args, opts \\ []) do
    Supervisor.start_link(__MODULE__, args, opts)
  end

  def init(args) do
    Logger.debug("[NEW] IrcSupervisor #{inspect self()}")

    # generate one irchandler per host
    children = args
    |> Enum.map(fn(arg) ->
      {:ok, client} = ExIrc.start_client!
      state = %State{arg | client: client}
      hostname = String.to_atom(arg.host)
      worker(Hal.IrcHandler, [state], [id: hostname])
    end)
    |> List.flatten

    supervise(children, strategy: :one_for_one)
  end

end
