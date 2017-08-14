defmodule Hal.Plugin.QuoteTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, pid} = Hal.Plugin.Quote.start_link()
    infos = %Hal.IrcHandler.Infos{
      msg: "", from: nil, host: "localhost", chan: ["#test"], pid: self(),
      answers: []
    }
    [infos: infos, pid: pid]
  end

  defp quick_msg(msg, context) do
    Hal.Plugin.Quote.manage_quote(context[:pid], msg, context[:infos])
    receive do
      {:answer, %Hal.IrcHandler.Infos{answers: [answers]}, :msg} -> answers
    end
  end

  test "get with no parameter will get us a random quote", context do
    answers = quick_msg("get", context)
    expected = "Can't find anything... weird."
    assert expected == answers
  end

  test "add with no parameter (empty quote) and delete it", context do
    answers = quick_msg("add", context)
    expected = "Quote 0 registered."
    assert expected == answers

    answers = quick_msg("del 0", context)
    expected = "Quote 0 successfully deleted."
    assert expected == answers
  end

  test "delete with no parameter", context do
    answers = quick_msg("del", context)
    expected = "Can't delete, where's the ID ?"
    assert expected == answers
  end

  test "delete with wrong id should always work", context do
    answers = quick_msg("add foo: bar", context)
    expected = "Quote 0 registered."
    assert expected == answers

    # try a non-existing ID
    answers = quick_msg("del 666", context)
    expected = "Quote 666 successfully deleted."
    assert expected == answers

    answers = quick_msg("del 0", context)
    expected = "Quote 0 successfully deleted."
    assert expected == answers
  end

end
