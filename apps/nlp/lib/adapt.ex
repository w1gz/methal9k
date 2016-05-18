defmodule NLP do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [

    ]

    opts = [strategy: :one_for_one, name: NLP.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
