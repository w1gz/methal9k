defmodule Hal.Plugin.Quote do
  @moduledoc """
  Manage famous quotes of a channel
  """

  use GenServer
  require Logger
  alias Hal.Tool, as: Tool

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def manage_quote(pid, quoted_action, infos) do
    quick_trim = fn(str, match) ->
      str
      |> String.replace_prefix(match, "")
      |> String.trim_leading()
    end

    action = case String.split(quoted_action) do
               []      -> ""
               [h | _] -> h
             end

    case action do
      "add" ->
        quote_msg = quick_trim.(quoted_action, action)
        GenServer.cast(pid, {:add, infos, quote_msg})
      "del" ->
        quote_cmd = quick_trim.(quoted_action, action)
        GenServer.cast(pid, {:del, infos, quote_cmd})
      "" ->
        GenServer.cast(pid, {:get, infos, ""})
      _ ->
        quote_msg = quoted_action |> String.trim_leading()
        GenServer.cast(pid, {:get, infos, quote_msg})
    end
  end

  def usage(pid) do
    GenServer.call(pid, :usage)
  end

  def init(args) do
    Logger.debug("[NEW] PluginQuote #{inspect self()}")
    :mnesia.create_table(Quote, [
          attributes: [
            :id,
            :time,
            :quote,
          ],
          type: :ordered_set,
          disc_copies: [node()]])
    {:ok, args}
  end

  def handle_call(:usage, _frompid, state) do
    answer = ".quote <add|del>? <msg> famous quotes start here"
    {:reply, answer, state}
  end

  def handle_cast({:add, infos, msg_to_quote}, state) do
    # construct dependencies for adding quote
    last_id = :mnesia.transaction(fn -> :mnesia.last(Quote) end)
    id = case last_id do
           {:atomic, :"$end_of_table"} -> 0
           {:atomic, last} -> last + 1
         end
    {:ok, time} = Timex.format(Timex.now(), "%D (%R UTC)", :strftime)

    # actual query
    query = fn -> :mnesia.write({Quote, id, time, msg_to_quote}) end
    answer = case :mnesia.transaction(query) do
               {:atomic, :ok} -> "Quote #{id} registered."
               _ -> "Quote can't be registered"
             end
    Tool.terminate(infos.pid, infos.uid, answer)
    {:noreply, state}
  end

  def handle_cast({:del, infos, quote_id}, state) do
    {id, _rem} = Integer.parse(quote_id)
    query = fn -> :mnesia.delete({Quote, id}) end
    answer = case :mnesia.transaction(query) do
               {:atomic, :ok}      -> "Quote #{id} successfully deleted."
               {:aborted, _reason} -> "Can't delete, something's wrong..."
             end
    Tool.terminate(infos.pid, infos.uid, answer)
    {:noreply, state}
  end

  def handle_cast({:get, infos, quote_or_id}, state) do
    aborted_msg = "Can't find anything... weird."

    query_with_integer = fn(id) ->
      # directly acces the quote with its id
      query = fn -> :mnesia.read({Quote, id}) end
      case :mnesia.transaction(query) do
        {:atomic, match} ->
          case Enum.at(match, 0) do
            nil -> aborted_msg
            {_Q, idx, time, msg} -> "[#{idx}] #{time} #{msg}"
          end
        {:aborted, _reason} -> aborted_msg
      end
    end

    query_with_keyword = fn(keyword) ->
      # look for the quote in :'$3' (msg field)
      query = fn -> :mnesia.match_object({Quote, :'_', :'$2', :'$3'}) end
      case :mnesia.transaction(query) do
        {:atomic, match} ->
          # TODO do the filter in the mnesia request?
          quotes = Enum.filter(match,
          fn({_Q, _id, _time, msg}) -> String.contains?(msg, keyword) end)
          rand_seed = max(length(quotes), 1)
          r = :rand.uniform(rand_seed) - 1
          case Enum.at(quotes, r) do
            nil -> aborted_msg
            {_Q, idx, time, msg} -> "[#{idx}] #{time} #{msg}"
          end
        {:aborted, _reason} -> aborted_msg
      end
    end

    # Choose between integer or string request
    answer = case Integer.parse(quote_or_id) do
               {id, _rem} -> query_with_integer.(id)
               :error     -> query_with_keyword.(quote_or_id)
             end
    Tool.terminate(infos.pid, infos.uid, answer)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.debug("[TERM] #{__MODULE__} #{inspect self()} -> #{inspect reason}")
    {:ok, reason}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

end
