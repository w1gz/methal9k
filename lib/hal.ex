defmodule Hal do
  @moduledoc """
  Initialize an IRC connection based on various credentials and parameters
  """

  use Application
  alias Hal.Tool, as: Tool

  defmodule State do
    @moduledoc """
    This module holds the global hal9k state in order to have a nice IRC
    connection. Those informations are:
    - `client` store the ExIrc client state
    - `host` irc host (chat.freenode.net)
    - `port`  irc port (6697)
    - `chans` irc channels (["#awesome-chan", "#pulp-fiction"]
    - `nick` login for the irc server
    - `pass` the associated password
    - `user` misc infos
    - `name` misc infos
    - `uids` ETS table storing the current jobs being run
    """

    defstruct client: nil,
      host: "127.0.0.1",
      port: 6697,
      chans: ["#hal", "#test"],
      nick: "hal",
      name: "hal",
      user: "hal",
      pass: "",
      uids: %{}
  end

  def start(_type, [credentials]) do
    import Supervisor.Spec, warn: false

    # read config file or fallback to internal configuration
    confs = parse_conf(credentials)

    # launch Mnesia
    :mnesia.create_schema([node()])
    :mnesia.start()

    # TODO test rust NIF
    defmodule HelloWorld do
      use Rustler, otp_app: :hal, crate: "helloworld"
      def add(_a, _b), do: throw :nif_not_loaded
    end

    # static processes
    children = [
      worker(Hal.Keeper, [[], [name: :hal_keeper]]),
      supervisor(Hal.IrcSupervisor, [confs, [name: :hal_irc_supervisor]]),
      supervisor(Hal.PluginSupervisor, [[], [name: :hal_plugin_supervisor]]),
      :poolboy.child_spec(:p_dispatcher, Tool.poolboy_conf(Hal.Dispatcher, 20, 10))
    ]
    Supervisor.start_link(children, [name: :hal, strategy: :one_for_one])
  end

  defp parse_conf(credentials) do
    try do
      YamlElixir.read_all_from_file(credentials)
    catch
      _ -> [%State{}]
    else
      [yaml] ->
        Enum.map(yaml["servers"], fn(s) ->
          %State{host: s["host"],
                 port: s["port"],
                 chans: s["chans"],
                 nick: s["nick"],
                 name: s["name"],
                 user: s["user"],
                 pass: s["pass"]}
        end)
    end
  end

end
