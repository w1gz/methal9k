defmodule Hal.Plugin.Time do
  @moduledoc """
  Provide Time capability, including timezone
  """

  use GenServer
  require Logger
  alias Timex.Timezone, as: Timezone
  alias Hal.Tool, as: Tool

  defmodule Credentials do
    @moduledoc """
    Holds the geocode `gc_id` and timezone `tz_id` tokens.
    """

    defstruct gc_id: nil,
      tz_id: nil
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def usage(pid) do
    GenServer.call(pid, :usage)
  end

  def current(pid, params, infos) do
    GenServer.cast(pid, {:get, params, infos})
  end

  def init(_state) do
    Logger.debug("[NEW] PluginTime #{inspect self()}")
    geo_id = Tool.read_token("lib/plugins/time/geo.sec")
    tz_id = Tool.read_token("lib/plugins/time/tz.sec")
    state = %Credentials{gc_id: geo_id, tz_id: tz_id}
    {:ok, state}
  end

  def handle_call(:usage, _frompid, state) do
    answer = ".time <tz|city> tz should follow the 'Country/City' format"
    {:reply, answer, state}
  end

  def handle_cast({:get, params, infos}, state) do
    current_time(params, infos, state)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.debug("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  defp current_time(params, infos, state) do
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
                   time_str = "%T in #{city} (%D), #{timezone} %:z UTC"
                   {:ok, current} = Timex.format(dt, time_str, :strftime)
                   current
               end
    Tool.terminate(infos.pid, infos.uid, time_res)
  end

  defp find_timezone(params, state) do
    # get geocode
    address = Enum.join(params, "+")
    gc_url = "https://maps.googleapis.com/maps/api/geocode/json?address=" <>
      "#{address}&key=#{state.gc_id}"
    gc_json = Tool.quick_request(gc_url)
    coord = hd(gc_json["results"])["geometry"]["location"]
    {lat, lng} = {coord["lat"], coord["lng"]}

    # find the timezone for this geocode
    {_, sec, _} = :erlang.timestamp()
    tz_url = "https://maps.googleapis.com/maps/api/timezone/json?location=" <>
      "#{lat},#{lng}&timestamp=#{sec}&key=#{state.tz_id}"
    tz_json = Tool.quick_request(tz_url)
    tz_json["timeZoneId"]
  end

end
