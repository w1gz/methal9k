use Mix.Config

import_config "../apps/*/config/config.exs"
import_config "#{Mix.env}.exs"

config :logger, :console,
  level: :info,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:user_id]
