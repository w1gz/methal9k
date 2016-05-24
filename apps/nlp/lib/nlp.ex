defmodule NLP do
  use Application

  def start(type, args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(NLP.Adapt, [args, [restart: :permanent, name: :nlp_adapt]])
    ]

    opts = [strategy: :one_for_one, name: :nlp_supervisor]
    Supervisor.start_link(children, opts)
  end

end
