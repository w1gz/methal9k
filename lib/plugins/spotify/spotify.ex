
defmodule Hal.Plugin.Spotify do
  @moduledoc """
  Query Spotify API for various information (artist, album, song etc.)
  """

  use GenServer
  require Logger
  alias Hal.Tool, as: Tool
  alias Hal.CommonHandler, as: Handler

  defmodule Credentials do
    @moduledoc """
    Holds the Spotify `client_id` and `client_secret` numbers.
    """

    defstruct id: nil, secret: nil
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def search(pid, params, infos) do
    GenServer.cast(pid, {:search, params, infos})
  end

  def usage(pid) do
    GenServer.call(pid, :usage)
  end

  def init(_state) do
    Logger.debug("[NEW] PluginSpotify #{inspect self()}")
    file = Path.join(:code.priv_dir(:hal), "spotify.sec")
    client_id = extract(file, "client_id")
    client_secret = extract(file, "client_secret")
    state = %Credentials{id: client_id, secret: client_secret}
    {:ok, _state}
  end

  def handle_call(:usage, _frompid, state) do
    answer = ".spotify <song|album|artist> <name> use spotify to fetch various music informations"
    {:reply, answer, state}
  end

  def handle_cast({:search, params, infos}, state) do
    # TODO
    # keywords = params |> String.trim()
    # answers = ddg_search(keywords)
    # infos = %Handler.Infos{infos | answers: answers}
    # Handler.terminate(infos)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.debug("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  defp extract(file, key) do
    Tool.read_token(file)
    |> String.split("\n")
    |> Enum.map(&(String.split(&1, "#{key}=")))
    |> List.flatten
    |> Enum.filter(&(&1 != ""))
    |> hd
  end

end
