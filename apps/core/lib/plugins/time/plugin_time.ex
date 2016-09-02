defmodule Core.PluginTime do
  @moduledoc """
  Provide Time capability, including timezone
  """

  use GenServer

  defmodule Credentials do
    defstruct gc_id: nil,
      tz_id: nil
  end

  # Client API
  def start_link(args, opts \\ []) do
    IO.puts("[INFO] New PluginTime")
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Fetches the current time for a city or timezone (tz format).

  `pid` the pid of the GenServer that will be called.

  `params` list of string containing either the city name or a timezone.

  `uid` is the unique identifier for this request. Whereas `frompid` is the
  process for which the answer will be sent.

  ## Examples
  ```Elixir
  iex> Core.PluginTime.current(pid, ["las", "vegas"], {uid, frompid})
  iex> Core.PluginTime.current(pid, ["America/Chicago"], {uid, frompid})
  ```
  """
  def current(pid, params, req) do
    GenServer.cast(pid, {:current_time, params, req})
  end


  # Server callbacks
  def init(_state) do
    # read tokens
    gc_id = read_file("apps/core/lib/plugins/time/geocode.sec")
    tz_id = read_file("apps/core/lib/plugins/time/timezone.sec")

    # construct our initial state
    new_state = %Credentials{gc_id: String.strip(gc_id), tz_id: String.strip(tz_id)}
    {:ok, new_state}
  end

  def handle_cast({:current_time, params, req}, state) do
    current_time(params, req, state)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end


  # Internal functions
  defp current_time(params, _req={uid, frompid}, state) do
    tz = hd(params)
    timezone = case Timex.Timezone.exists?(tz) do
                 true -> tz
                 false ->
                   # get geocode
                   url = "https://maps.googleapis.com/maps/api/geocode/json?address="
                   address = Enum.join(params, "+")
                   gc_url = url <> "#{address}&key=#{state.gc_id}"
                   gc_json = quick_request(gc_url)
                   coord = hd(gc_json["results"])["geometry"]["location"]
                   {lat, lng} = {coord["lat"], coord["lng"]}

                   # find the timezone for this geocode
                   {mgs, sec, ms} = :erlang.timestamp()
                   url = "https://maps.googleapis.com/maps/api/timezone/json?location="
                   tz_url = url <> "#{lat},#{lng}&timestamp=#{sec}&key=#{state.tz_id}"
                   tz_json = quick_request(tz_url)
                   tz_json["timeZoneId"]
               end
    city = Enum.join(params, " ")
    dt = Timex.now(timezone)
    {:ok, current} = Timex.format(dt, "%F - %T in #{city} (#{timezone}, %:z UTC)", :strftime)
    send frompid, {:answer, {uid, [current]}}
  end

  defp read_file(file) do
    tname = List.last(String.split(file, "/"))
    {id, msg} = case File.read(file) do
                  {:ok, id} -> {id, "[INFO] #{tname} successfully read"}
                  _          -> {"",  "[WARN] #{tname} not found"}
                end
    IO.puts(msg)
    id
  end

  defp quick_request(url) do
    with {:ok, res} <- HTTPoison.get(url, []), %HTTPoison.Response{body: body} <- res do
      Poison.decode!(body)
    end
  end

end
