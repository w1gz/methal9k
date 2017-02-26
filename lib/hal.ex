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
      host: "172.17.0.2",
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

    # read config file or fallback to internal configuration
    confs = try do
              YamlElixir.read_all_from_file(credentials)
            catch
              _ -> [%State{}]
            else
              [yaml] -> case yaml do
                          %{} -> throw("is #{credentials} a proper yaml file?")
                          _ ->
                            servers = yaml["servers"]
                            parse_conf(servers)
                        end
            end

    # launch Mnesia
    :mnesia.create_schema([node()])
    :mnesia.start()

    # static processes
    children = [
      worker(Hal.Keeper, [[], [name: :hal_keeper]]),
      worker(Hal.Shepherd, [[], [name: :hal_shepherd]]),
      supervisor(Hal.IrcSupervisor, [confs, []])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp parse_conf(servers) do
    Enum.map(servers, fn(s) ->
      %State{host: s["host"],
             port: s["port"],
             chans: s["chans"],
             nick: s["nick"],
             user: s["user"],
             name: s["name"],
             pass: s["pass"]}
    end)
  end

end
