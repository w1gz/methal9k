defmodule Hal.Plugin.ReminderTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, pid} = Hal.Plugin.Reminder.start_link()
    infos = %Hal.IrcHandler.Infos{
      msg: "", from: nil, host: "localhost", chan: ["#test"], pid: self(),
      answers: []
    }
    [infos: infos, pid: pid]
  end

  defp quick_msg(msg, context) do
    Hal.Plugin.Reminder.current(context[:pid], msg, context[:infos])
    receive do
      {:answer, %Hal.IrcHandler.Infos{answers: [answers]}, :msg} -> answers
    end
  end

  test "No arguments", context do
    # answers = quick_msg([], context)
    # expected = "Missing arguments."
    # assert expected == answers
  end

  test "set reminder", context do
  end

  test "get reminder (pseudo just /join)", context do
  end

end
