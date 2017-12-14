Path.join(["rel", "plugins", "*.exs"])
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Mix.Releases.Config,
    default_release: :hal,
    default_environment: :prod

environment :prod do
  set include_erts: true
  set include_system_libs: true
  set include_src: false
  set cookie: :prod
end

release :hal do
  set version: current_version(:hal)
  set applications: [:runtime_tools]
end

