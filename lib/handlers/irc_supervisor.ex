defmodule Hal.IrcSupervisor do
  @moduledoc """
  Supervise the various connection handler (IRC) with a simple_one_for_one
  strategy.
  """

  use Supervisor
  alias Hal.State, as: State

  def start_link(args, opts \\ []) do
    Supervisor.start_link(__MODULE__, args, opts)
  end

  def init(args) do
    IO.puts "[NEW] IrcSupervisor #{inspect self()}"

    # generate one irchandler per host
    children = args
    |> Enum.map(fn(arg) ->
      {:ok, client} = ExIrc.start_client!
      state = %State{arg | client: client}
      worker(Hal.IrcHandler, [state], id: String.to_atom(arg.host))
    end)
    |> List.flatten

    supervise(children, strategy: :one_for_one)
  end

end
