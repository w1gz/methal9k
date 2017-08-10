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
    Tool.terminate(self(), infos.pid, infos.uid, answers)
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
    request = fn(url) ->
      res = HTTPoison.get(url, [], [follow_redirect: true, max_redirect: 15])
      case res do
        {:ok, %HTTPoison.Response{body: body}} -> body
        _ -> ""
      end
    end

    match? = fn(body) ->
      Regex.scan(~r/<title>(.*?)<\/title>/si, body, capture: :all_but_first)
      |> List.flatten
    end

    with body <- request.(url),
         match <- match?.(body),
           [title | _] <- match do
      HtmlEntities.decode(title)
    else
      [] -> "Can't find the title"
    end
  end

end
