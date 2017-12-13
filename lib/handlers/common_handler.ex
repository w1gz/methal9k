defmodule Hal.CommonHandler do
  @moduledoc """
  Common code between various handler
  """

  require Logger
  alias Hal.Dispatcher, as: Dispatcher
  alias Hal.Plugin.Web, as: Web

  defmodule Infos do
    defstruct msg: "",
      from: nil,
      host: nil,
      chan: [],
      pid: nil,
      answers: []
  end

  def check_command(infos) do
    case String.at(infos.msg, 0) do
      "." ->
        :poolboy.transaction(Dispatcher, fn(pid) ->
          Dispatcher.command(pid, infos)
        end)
        :ok
      _ -> nil
    end
  end

  def check_url(infos) do
    urls = Regex.scan(~r{https?://[^\s]+}, infos.msg) |> List.flatten
    case urls do
      [] -> nil
      _ -> :poolboy.transaction(Web, fn(pid) -> Web.preview(pid, urls, infos) end)
    end
  end

  def terminate(infos, type \\ :msg) do
    case infos.answers do
      [nil] -> nil
      _ ->
        Logger.debug("Sending back #{inspect infos.answers}")
        send infos.pid, {:answer, infos, type}
    end
  end

end
