# defmodule Hal.SlackHandler do
#   @moduledoc """
#   The module will maintain a link to the ExSlack library in order to intercept and
#   send message to SLACK.
#   """

#   use Slack
#   require Logger
#   alias Hal.CommonHandler, as: Handler

#   def handle_connect(slack, state) do
#     Logger.info("Connected as #{slack.me.name}")
#     {:ok, state}
#   end

#   def handle_event(m = %{type: "message"}, slack, state) do
#     case Map.get(m, :text) do
#       nil -> {:ok, state}
#       _ ->
#         infos = %Handler.Infos{msg: m.text, from: m.user, host: slack, chan: m.channel, pid: self()}
#         Handler.check_command(infos) # in Slack, we don't care (yet) for this result
#     end
#     {:ok, state}
#   end

#   def handle_event(msg, _, state) do
#     Logger.debug("Unsupported event type #{inspect msg.type}")
#     {:ok, state}
#   end

#   def handle_close(reason, _slack, state) do
#     Logger.warn("Connection closed: #{inspect reason}")
#     {:ok, state}
#   end

#   def handle_info({:answer, infos, _type}, _slack, state) do
#     infos.answers
#     |> Enum.filter(fn(x) -> x != nil end)
#     |> Enum.each(fn(answer) -> send_message(answer, infos.chan, infos.host) end)
#     {:ok, state}
#   end

#   def handle_info(msg , _, state) do
#     Logger.debug("#{inspect msg}")
#     {:ok, state}
#   end

# end
