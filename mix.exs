defmodule Methal9k.Mixfile do
  use Mix.Project

  def project do
    [app: :hal,
     version: "0.2.0",
     elixir: "~> 1.4",
     description: description(),
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [
      applications: [
        :mnesia,
        :exirc,
        :html_entities,
        :httpoison,
        :poison,
        :poolboy,
        :slack,
        :timex,
        :yaml_elixir
      ],
      extra_applications: [:logger],
      mod: {Hal, []}
    ]
  end

  defp deps do
    [
      {:exirc, ">= 1.0.0"},
      {:slack, ">= 0.12.0"},
      {:httpoison, ">= 0.11.0"},
      {:poison, ">= 3.1.0"},
      {:timex, ">= 3.1.11"},
      {:yaml_elixir, ">= 1.3.0"},
      {:html_entities, ">= 0.3.0"},
      {:poolboy, ">= 1.5.1"},
      {:distillery, ">= 1.5.1", runtime: false},
      {:credo, ">= 0.6.1", only: :dev},
      {:ex_doc, ">= 0.14.5", only: :dev},
      {:excoveralls, ">= 0.6.2", only: :test}
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
