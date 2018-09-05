defmodule Methal9k.Mixfile do
  use Mix.Project

  def project do
    [app: :hal,
     version: "0.2.0",
     elixir: "~> 1.6",
     description: description(),
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [
      extra_applications: [:logger],
      included_applications: [:mnesia],
      mod: {Hal, []}
    ]
  end

  defp deps do
    [
      {:exirc, ">= 1.0.1"},
      # {:slack, ">= 0.15.0"}, # deactivated for now
      {:httpoison, ">= 1.3.0"},
      {:poison, ">= 4.0.1"},
      {:timex, ">= 3.3.0"},
      {:yaml_elixir, ">= 2.1.0"},
      {:html_entities, ">= 0.4.0"},
      {:poolboy, ">= 1.5.1"},
      {:distillery, ">= 2.0.9", runtime: false},
      {:credo, ">= 0.10.0", only: :dev},
      {:ex_doc, ">= 0.19.1", only: :dev},
      {:excoveralls, ">= 0.10.0", only: :test}
    ]
  end

  defp description do
    """
    Hal, a simple IRC bot
    """
  end

  defp package do
    [
      files: ["lib", "test", "config", "mix.exs"],
      maintainers: ["w1gz"],
      licenses: ["GPLv3"],
      links: %{"GitHub": "https://github.com/w1gz/methal9k"}
    ]
  end
end
