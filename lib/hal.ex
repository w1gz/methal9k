defmodule Hal do
  @moduledoc """
  Initialize an IRC connection based on various credentials and parameters
  """

  use Application

  defmodule State do
    @moduledoc """
    This module holds the global hal9k state in order to have a nice IRC
    connection. Those informations are:
    - `client` store the ExIrc client state
    - `host` irc host (chat.freenode.net)
    - `port`  irc port (6667)
    - `chans` irc channels (["#awesome-chan", "#pulp-fiction"]
    - `nick` login for the irc server
    - `pass` the associated password
    - `user` misc infos
    - `name` misc infos
    - `uids` ETS table storing the current jobs being run
    """

    defstruct client: nil,
      host: "127.0.0.1",
      port: 6667,
      chans: ["#hal", "#test"],
      nick: "hal",
      user: "hal",
      name: "hal",
      pass: "",
      uids: %{}
  end

  def start(_type, [credentials]) do
    import Supervisor.Spec, warn: false

    # try to read config file
    confs = try do
              YamlElixir.read_all_from_file(credentials)
            rescue
              _ -> [Map.new()]
            else
              [yaml] -> import_conf(yaml["servers"])
            end

    # launch Mnesia
    :mnesia.create_schema([node()])
    :mnesia.start()

    global_workers = [
      worker(Hal.Keeper, [[], [name: :hal_keeper]]),
      worker(Hal.Shepherd, [[], [name: :hal_shepherd]]),
    ]

    # TODO accept multiple servers instead of the first one
    handlers = Enum.map(confs, fn(args) -> [
      supervisor(Hal.IrcSupervisor, [args, []])
    ] end)

    children = global_workers ++ hd(handlers) # TODO remove hd
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp import_conf(servers) do
    Enum.map(servers, fn(s) ->
      {:ok, client} = ExIrc.start_client!
      %State{client: client,
             port: s["port"],
             chans: s["chans"],
             nick: s["nick"],
             user: s["user"],
             name: s["name"],
             pass: s["pass"]}
    end)
  end

end
