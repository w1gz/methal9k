defmodule Hal do
  @moduledoc """
  Initialize an IRC connection based on various credentials and parameters
  """

  use Application

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
  defmodule State do
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

  def start(type, [credentials]) do
    import Supervisor.Spec, warn: false

    # parse connection/server infos
    data = case File.read("apps/hal9k/" <> credentials) do
             {:ok, data} -> data
             {:error, _reason} -> # provides a "dummy" conf
               "[local]\nnick: hal\nuser: hal\nname: hal\nhost: 127.0.0.1\nport: 6667\npass: \nchans: #yolo, #too, #hal\n"
           end
    match = Regex.named_captures(~r/\[.*\]\n(?<server>.*)\n+\[?/muis, data)

    # format for our internal struture
    conf = String.split(match["server"], "\n")
    |> Enum.map(fn(line) ->
      [name|value] = String.split(line, ": ")
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
    IO.puts("[INFO] credentials were successfully read")

    # start everything up
    {:ok, client} = ExIrc.start_client!
    args = %State{client: client} |> Map.merge(conf)

    children = [
      supervisor(Hal.HandlerSupervisor, [type, args], restart: :permanent)
    ]

    opts = [strategy: :one_for_one, name: :hal_supervisor]
    Supervisor.start_link(children, opts)
  end

end
