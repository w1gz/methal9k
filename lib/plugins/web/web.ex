defmodule Hal.Plugin.Web do
  @moduledoc """

  """

  use GenServer
  require Logger
  alias Hal.Tool, as: Tool
  alias Hal.IrcHandler, as: Irc

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def preview(pid, urls, infos) do
    GenServer.cast(pid, {:preview, urls, infos})
  end

  def search(pid, params, infos) do
    GenServer.cast(pid, {:web_search, params, infos})
  end

  def usage(pid) do
    GenServer.call(pid, :usage)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:usage, _frompid, state) do
    answer = ".web <keyword> query DuckDuckGo through the Instant Answer API"
    {:reply, answer, state}
  end

  def handle_cast({:preview, urls, infos}, state) do
    answers = urls |> Enum.filter(&(&1 != "")) |> Enum.map(&(get_title(&1)))
    infos = %Irc.Infos{infos | answers: answers}
    Tool.terminate(infos)
    {:noreply, state}
  end

  def handle_cast({:web_search, params, infos}, state) do
    # [engine | _] = String.split(params)
    # keywords = params
    # |> String.replace_prefix(engine, "")
    # |> String.trim_leading()

    # answers = case engine do
    #             "goo" -> goo_search(keywords)
    #             "ddg" -> ddg_search(keywords)
    #             _     -> ["Wrong arguments."]
    # end

    keywords = params |> String.trim()
    answers = ddg_search(keywords)
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

  defp ddg_search(keywords) do
    url = "http://api.duckduckgo.com/?q=#{keywords}&format=json"
    json = Tool.quick_request(url)
    parse_ddg(json)
  end

  # defp goo_search(keywords) do
  # url = "http://api.duckduckgo.com/?q=#{keywords}!g&format=json"
  # json = Tool.quick_request(url)
  # parse_ddg(json)
  # end

  defp parse_ddg(json) do
    heading = Map.get(json, "Heading", "")
    url = Map.get(json, "AbstractURL", "")
    text = Map.get(json, "AbstractText", "")
    answers = if url == "" do "ø" else "#{heading} #{url}" |> String.trim() end

    # if nothing revelant is found, we dig through the related topics
    text = with "" <- text,
                [topic|_] <- Map.get(json, "RelatedTopics") do
             Map.get(topic, "Text", "")
           else
             _ -> text
           end

    # truncate and pretty print our message
    case text do
      "" -> [answers]
      _ ->
        text = String.slice(text, 0, 240)
        [answers, "#{text} ^C^C^C"]
    end
  end

  defp get_title(url) do
    data = case Tool.get(url) do
             {:ok, resp} -> Tool.request(resp)
             {:error, %HTTPoison.Error{id: _, reason: reason}} -> %{code: reason, body: ""}
           end

    # we always check for a title, even on status_code != 200
    reg = Regex.scan(~r{<title>(.*?)</title>}si, data[:body], capture: :all_but_first) |> List.flatten
    case reg do
      [title | _] -> HtmlEntities.decode(title)
      _ -> nil
    end
  end

end
