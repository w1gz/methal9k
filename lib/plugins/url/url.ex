defmodule Hal.Plugin.Url do
  @moduledoc """
  Tries to fetch the <title> tag of an HTML page
  """

  use GenServer
  require Logger
  alias Hal.Tool, as: Tool
  alias Hal.IrcHandler, as: Irc
  @tool_url Application.get_env(:hal, :tool_get_url)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def preview(pid, urls, infos) do
    GenServer.cast(pid, {:preview, urls, infos})
  end

  def usage(pid) do
    GenServer.call(pid, :usage)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:usage, _frompid, state) do
    answer = ".url <link> extract the title tag from the url link provided"
    {:reply, answer, state}
  end

  def handle_cast({:preview, urls, infos}, state) do
    answers = urls |> Enum.filter(&(&1 != "")) |> Enum.map(&(get_title(&1)))
    infos = %Irc.Infos{infos | answers: answers}
    Tool.terminate(infos)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.debug("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  defp get_title(url) do
    data = @tool_url.get(url)
    # we always check for a title, even on status_code != 200
    reg = Regex.scan(~r{<title>(.*?)</title>}si, data[:body], capture: :all_but_first) |> List.flatten
    case reg do
      [title | _] -> HtmlEntities.decode(title)
      _ -> nil
    end
  end

end
