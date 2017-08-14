defmodule Hal.Plugin.UrlTest do
  use ExUnit.Case, async: true

  test "Fetch the title tag of methal9k's github" do
    infos = %Hal.IrcHandler.Infos{msg: "", from: nil,
                                  host: "localhost", chan: ["#test"],
                                  pid: self(), answers: []}
    Hal.Plugin.Url.handle_cast({:preview, ["https://github.com/w1gz/methal9k"], infos}, nil)
    answers = receive do
      {:answer, %Hal.IrcHandler.Infos{answers: [answers]}, :msg} ->
        answers |> String.trim |> String.split("\n") |> Enum.join(" ")
    end
    expected = "GitHub - w1gz/methal9k: Home of Meta Hal 9000 -- IRC bot & more"
    assert expected == answers
  end

end
