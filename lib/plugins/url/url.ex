defmodule Hal.Plugin.Url do
  @moduledoc """

  """

  use GenServer
  require Logger
  alias Hal.Tool, as: Tool

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def preview(pid, urls, infos) do
    GenServer.cast(pid, {:preview, urls, infos})
  end

  def usage(pid) do
    GenServer.call(pid, :usage)
  end

  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_call(:usage, _frompid, state) do
    answer = ".url <link> extract the title tag from the url link provided"
    {:reply, answer, state}
  end

  def handle_cast({:preview, urls, infos}, state) do
    answers = urls
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&(get_title(&1)))
    Tool.terminate(infos.pid, infos.uid, answers)
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
    data = case Tool.get(url) do
             {:ok, resp} -> Tool.request(resp)
             {:error, %HTTPoison.Error{id: _, reason: reason}} -> %{code: reason, body: ""}
           end

    # we always check for a title, even on status_code != 200
    reg = Regex.scan(~r/<title>(.*?)<\/title>/si, data[:body], capture: :all_but_first) |> List.flatten
    case reg do
      [title | _] -> HtmlEntities.decode(title)
      _ -> nil
    end
  end

end
