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
    - `chans` irc channels (["#awesome-chan", "pulp-fiction"]
    - `nick` login for the irc server
    - `pass` the associated password
    - `user` misc infos
    - `name` misc infos
    - `uids` ETS table storing the current jobs being run
    """

    defstruct client: nil,
      host: nil,
      port: nil,
      chans: nil,
      nick: nil,
      pass: nil,
      user: nil,
      name: nil,
      uids: nil
  end

  def start(_type, [credentials]) do
    import Supervisor.Spec, warn: false

    # parse connection/server infos
    data = case File.read("apps/hal9k/" <> credentials) do
             {:ok, data} -> data
             {:error, _reason} ->
               # provides a "dummy" configuration
               "[local]\n" <>
                 "nick: hal\n" <>
                 "user: hal\n" <>
                 "name: hal\n" <>
                 "host: 127.0.0.1\n" <>
                 "port: 6667\n" <>
                 "pass: \n" <>
                 "chans: #yolo, #too, #hal\n"
           end
    match = Regex.named_captures(~r/\[.*\]\n(?<server>.*)\n+\[?/muis, data)

    # format for our internal struture
    conf = format_internal_state(match)
    IO.puts("[INFO] credentials were successfully read")

    # start everything up
    {:ok, client} = ExIrc.start_client!
    args = %State{client: client} |> Map.merge(conf)
    children = [
      worker(Hal.Keeper, [[], [name: :hal_keeper]]),
      worker(Hal.Shepherd, [[], [name: :hal_shepherd]]),
      supervisor(Hal.IrcSupervisor, [args, [name: :hal_irc_supervisor]]),
      supervisor(Hal.PluginSupervisor, [args, [name: :hal_plugin_supervisor]])
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp format_internal_state(match) do
    match["server"]
    |> String.split("\n")
    |> Enum.map(fn(line) ->
      [name | value] = String.split(line, ": ")
      case name do
        "port" ->
          {String.to_atom(name), String.to_integer(hd(value))}
        "chans" ->
          value = String.split(hd(value), ", ")
          {String.to_atom(name), value}
        _ ->
          {String.to_atom(name), hd(value)}
      end
    end)
    |> Map.new(&(&1))
  end

end
