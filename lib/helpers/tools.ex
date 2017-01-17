defmodule Hal.Tool do
  @moduledoc """
  Helpers/Tools for commonly used functions
  """

  alias Hal.Shepherd, as: Herd

  @doc """
  Return and convert (if need be) its argument to a list.

  `something` the data you want to ensure is a list.
  """
  def convert_to_list(something) do
    case is_list(something) do
      true -> something
      false -> [something]
    end
  end

  @doc """
  Kill a process and send its answer to the appropriate process.

  `pid` the pid of the GenServer that will be called.

  `dest` the process to which the `answer` should be sent.

  `uid` the uid generated for this request.

  `answer` formed by a couple of `uid` and `answers`, answers being a list of
  string.
  """
  def terminate(pid, dest, uid, answer) do
    {pids, answers} = {convert_to_list(pid), convert_to_list(answer)}
    case answers do
      [nil] -> nil
      _ -> send dest, {:answer, {uid, answers}}
    end

    Herd.stop(:hal_shepherd, pids)
  end

  @doc """
  Kill a process and send its answer to the appropriate process.

  `pid` the pid of the GenServer that will be called.

  `dest` the process to which the `answer` should be sent.

  `chan` channel from which the request was initiated.

  `from` the username from which the request was initiated.

  `answer` formed by a tuple of `chan` , `from` and `answers`, answers being
  a list of string.
  """
  def terminate(pid, dest, chan, from, answer) do
    {pids, answers} = {convert_to_list(pid), convert_to_list(answer)}
    send dest, {:answer, {chan, from, answers}}
    Herd.stop(:hal_shepherd, pids)
  end

end
