defmodule Hal.Plugin.TimeTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, pid} = Hal.Plugin.Time.start_link()
    infos = %Hal.IrcHandler.Infos{
      msg: "", from: nil, host: "localhost", chan: ["#test"], pid: self(),
      answers: []
    }
    [infos: infos, pid: pid]
  end

  defp quick_msg(msg, context) do
    Hal.Plugin.Time.current(context[:pid], msg, context[:infos])
    receive do
      {:answer, %Hal.IrcHandler.Infos{answers: [answers]}, :msg} -> answers
    end
  end

  test "No arguments", context do
    answers = quick_msg([], context)
    expected = "Missing arguments."
    assert expected == answers
  end

  test "Timezone exists (i.e. local resolution)", context do
    timezone = "America/Chicago"
    dt = Timex.now(timezone)
    answers = quick_msg(["#{timezone}"], context)
    time_str = "%T in #{timezone} (%D), #{timezone} %:z UTC"
    {:ok, expected} = Timex.format(dt, time_str, :strftime)
    assert expected == answers
  end

end
