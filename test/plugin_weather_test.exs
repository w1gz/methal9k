defmodule Hal.Plugin.WeatherTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, pid} = Hal.Plugin.Weather.start_link()
    infos = %Hal.IrcHandler.Infos{
      msg: "", from: nil, host: "localhost", chan: ["#test"], pid: self(),
      answers: []
    }
    [infos: infos, pid: pid]
  end

  defp quick_msg(msg, context) do
    Hal.Plugin.Weather.current(context[:pid], msg, context[:infos])
    receive do
      {:answer, %Hal.IrcHandler.Infos{answers: [answers]}, :msg} -> answers
    end
  end

  test "No arguments", context do
    # answers = quick_msg([], context)
    # expected = "Missing arguments."
    # assert expected == answers
  end

  test "Missing arguments for current", context do
  end

  test "Missing arguments for hourly", context do
  end

  test "Missing arguments for daily", context do
  end

  test "get current", context do
  end

  test "get hourly", context do
  end

  test "get daily", context do
  end

end
