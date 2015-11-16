defmodule Hal do
  use Application

  defmodule State do
    defstruct client: nil,
    host: nil,
    port: nil,
    chans: nil,
    pass: nil,
    nick: nil,
    user: nil,
    name: nil,
    uids: nil
  end

  def start(type, [credentials]) do
    import Supervisor.Spec, warn: false

    # read file & retrieve raw server infos
    {:ok, data} = File.read("apps/hal9k/" <> credentials)
    match = Regex.named_captures(~r/\[.*\]\n(?<server>.*)\n\n\[/muis, data)

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
      supervisor(Hal.HandlerSupervisor, [type, args], restart: :permanent),
      supervisor(Hal.PluginSupervisor, [type, args], restart: :permanent)
    ]

    opts = [strategy: :one_for_one, name: :hal_supervisor]
    Supervisor.start_link(children, opts)
  end

end
