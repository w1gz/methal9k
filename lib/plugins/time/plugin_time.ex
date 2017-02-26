defmodule Hal.PluginTime do
  @moduledoc """
  Provide Time capability, including timezone
  """

  use GenServer
  alias Timex.Timezone, as: Timezone
  alias Hal.Tool, as: Tool

  defmodule Credentials do
    @moduledoc """
    Holds the geocode `gc_id` and timezone `tz_id` tokens.
    """

    defstruct gc_id: nil,
      tz_id: nil
  end

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @doc """
  Fetches the current time for a city or timezone (tz format).

  `pid` the pid of the GenServer that will be called.

  `params` list of string containing either the city name or a timezone.

  `uid` is the unique identifier for this request. Whereas `frompid` is the
  process for which the answer will be sent.
  """
  def current(pid, params, req) do
    GenServer.cast(pid, {:get, params, req})
  end

  # Server callbacks
  def init(_state) do
    IO.puts("[NEW] PluginTime #{inspect self()}")
    # read tokens
    gc_id = read_file("lib/plugins/time/geo.sec")
    tz_id = read_file("lib/plugins/time/tz.sec")

    # construct our initial state
    state = %Credentials{
      gc_id: String.trim(gc_id),
      tz_id: String.trim(tz_id)
    }

    {:ok, state}
  end

  def handle_cast({:get, params, req}, state) do
    current_time(params, req, state)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    IO.puts("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  # Internal functions
  defp current_time(params, {uid, frompid}, state) do
    time_res = case params do
                 [] -> "Missing arguments"
                 _ ->
                   tz = hd(params)
                   timezone = case Timezone.exists?(tz) do
                                true -> tz
                                false -> find_timezone(params, state)
                              end
                   city = Enum.join(params, " ")
                   dt = Timex.now(timezone)
                   time_str = "%F - %T in #{city} (#{timezone}, %:z UTC)"
                   {:ok, current} = Timex.format(dt, time_str, :strftime)
                   current
               end
    Tool.terminate(self(), frompid, uid, time_res)
  end

  defp find_timezone(params, state) do
    # get geocode
    address = Enum.join(params, "+")
    gc_url = "https://maps.googleapis.com/maps/api/geocode/json?address=" <>
      "#{address}&key=#{state.gc_id}"
    gc_json = quick_request(gc_url)
    coord = hd(gc_json["results"])["geometry"]["location"]
    {lat, lng} = {coord["lat"], coord["lng"]}

    # find the timezone for this geocode
    {_, sec, _} = :erlang.timestamp()
    tz_url = "https://maps.googleapis.com/maps/api/timezone/json?location=" <>
      "#{lat},#{lng}&timestamp=#{sec}&key=#{state.tz_id}"
    tz_json = quick_request(tz_url)
    tz_json["timeZoneId"]
  end

  defp read_file(file) do
    tname = List.last(String.split(file, "/"))
    {id, msg} = case File.read(file) do
                  {:ok, id} -> {id, "[INFO] #{tname} successfully read"}
                  _         -> {"",  "[WARN] #{tname} not found"}
                end
    IO.puts(msg)
    id
  end

  defp quick_request(url) do
    with {:ok, res} <- HTTPoison.get(url, []),
         %HTTPoison.Response{body: body} <- res do
      Poison.decode!(body)
    end
  end

end
