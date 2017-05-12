defmodule Hal.Plugin.Url do
  @moduledoc """

  """

  use GenServer
  alias Hal.Tool, as: Tool

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def preview(pid, urls, req) do
    GenServer.cast(pid, {:preview, urls, req})
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

  def handle_cast({:preview, urls, req}, state) do
    {uid, from} = req
    answers = Enum.map(urls, fn(url) -> get_title(url) end)
    Tool.terminate(self(), from, uid, answers)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    IO.puts("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  defp get_title(url) do
    with {:ok, %HTTPoison.Response{body: body}} <- HTTPoison.get(url) do
      html_title = Regex.scan(~r/<title>(.*)<\/title>/, body, capture: :all_but_first)
      title = hd(List.flatten(html_title))
      HtmlEntities.decode(title)
    end
  end

end
