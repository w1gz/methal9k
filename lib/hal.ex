defmodule Hal do
  @moduledoc """
  Initialize an IRC connection based on various credentials and parameters
  """

  use Application
  require Logger
  alias Hal.Tool, as: Tool

  defmodule State do
    @moduledoc """
    This module holds the global hal9k state in order to have a nice IRC
    connection. Those informations are:
    - `client` store the ExIrc client state
    - `host` irc server to connect to
    - `port`  irc server port
    - `chans` irc channels
    - `nick` login for the irc server
    - `pass` the associated password
    - `user` misc infos
    - `name` misc infos
    """

    defstruct client: nil,
      host: "localhost",
      port: 6697,
      chans: ["#hal", "#test"],
      nick: "hal",
      name: "hal",
      user: "hal",
      pass: ""
  end

  def start(_type, []) do
    import Supervisor.Spec, warn: false

    # read config file or fallback to internal configuration
    priv_dir = :code.priv_dir(:hal)
    credentials = Path.join(priv_dir, "credz.sec")
    irc_conf = parse_irc_conf(credentials)
    # slack_conf = parse_slack_conf(credentials)

    # launch Mnesia
    with :ok <- :mnesia.create_schema([node()]),
         :ok <- :mnesia.start() do
      Logger.debug("Mnesia successfully started")
    else
      error -> Logger.debug("Mnesia failed to start: #{inspect error}")
    end

    # static processes
    children = [
      worker(Hal.Keeper, [[], [name: :hal_keeper]]),
      supervisor(Hal.IrcSupervisor, [irc_conf, [name: :hal_irc_supervisor]]),
      # supervisor(Hal.SlackSupervisor, [slack_conf, [name: :hal_slack_supervisor]]),
      supervisor(Hal.PluginSupervisor, [[], [name: :hal_plugin_supervisor]]),
      :poolboy.child_spec(:p_dispatcher, Tool.poolboy_conf(Hal.Dispatcher))
    ]
    Supervisor.start_link(children, [name: :hal, strategy: :one_for_one])
  end

  # defp parse_slack_conf(credentials) do
  #   case YamlElixir.read_all_from_file(credentials) do
  #     {:ok, [yaml]} ->
  #       Enum.map(yaml["slack"], fn(s) ->
  #         %{token: s["token"], host: s["host"]}
  #       end)
  #     _ -> [""]
  #   end
  # end

  defp parse_irc_conf(credentials) do
    case YamlElixir.read_all_from_file(credentials) do
      {:ok, [yaml]} ->
        Enum.map(yaml["irc"], fn(s) ->
          %State{host: s["host"],
                 port: s["port"],
                 chans: s["chans"],
                 nick: s["nick"],
                 name: s["name"],
                 user: s["user"],
                 pass: s["pass"]}
        end)
      _ -> [%State{}]
    end
  end

end
