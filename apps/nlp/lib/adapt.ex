defmodule NLP.Adapt do
  use GenServer

  # Client API
  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def register_weather(pid) do
    GenServer.cast(pid, {:register_weather})
  end

  def register_time(pid) do
    GenServer.cast(pid, {:register_time})
  end

  def determine_intent(pid, intent) do
    GenServer.call(pid, {:intent, intent})
  end


  # Server callbacks
  def init(_default) do
    {:ok, state} = :python.start([{:"python_path", ['apps/nlp/lib/aintent']}])
    :python.call(state, :"weather_time", :"register_weather", [])
    :python.call(state, :"weather_time", :"register_time", [])
    {:ok, state}
  end

  def handle_cast({:register_weather}, state) do
    :python.call(state, :"weather_time", :register_weather, [])
    {:ok, state}
  end

  def handle_cast({:register_time}, state) do
    :python.call(state, :"weather_time", :register_time, [])
    {:ok, state}
  end

  def handle_call({:intent, intent}, _frompid, state) do
    intent = :python.call(state, :"weather_time", :run, [intent])
    {:reply, intent, state}
  end

end
