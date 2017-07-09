defmodule Hal.Tool do
  @moduledoc """
  Helpers/Tools for commonly used functions
  """

  alias Hal.Shepherd, as: Herd

  def terminate(pid) do
    Herd.stop(:hal_shepherd, [pid])
  end

  @doc """
  Kill a process and send its answer to the appropriate process.

  `pid` the pid of the GenServer that will be called.

  `dest` the process to which the `answer` should be sent.

  `uid` the uid generated for this request.

  `answers` a list of string. If a string is sent, it will be wrapped inside
  a list
  """
  def terminate(pid, dest, uid, answer) when not is_list(answer) do
    terminate(pid, dest, uid, [answer])
  end

  def terminate(pid, dest, uid, answers) do
    case answers do
      [nil]  -> nil
      _      -> send dest, {:answer, uid, answers}
    end
    Herd.stop(:hal_shepherd, [pid])
  end

  # # helper for the future cron that will clean ets/mnesia tables?
  # defp shift_time(time, unit \\ :days, timeshift \\ 7) do
    #     case unit do
    #       :days    -> Timex.shift(time, days: timeshift)
    #       :hours   -> Timex.shift(time, hours: timeshift)
    #       :minutes -> Timex.shift(time, minutes: timeshift)
  #     :seconds -> Timex.shift(time, seconds: timeshift)
  #   end
  # end

end
