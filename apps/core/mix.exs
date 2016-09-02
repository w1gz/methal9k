defmodule Core.Mixfile do
  use Mix.Project

  def project do
    [app: :core,
     version: "0.10.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.3",
     description: description(),
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [
        :logger,
        :httpoison,
        :poison,
        :timex,
      ], mod: {Core, []}]
  end

  defp deps do
    [
      {:httpoison, "~> 0.9.0"},
      {:poison, "~> 2.2.0"},
      {:timex, "3.0.8"},
    ]
  end

  defp description do
    """
    Dispatcher, the Brain of methal9k
    """
  end

  defp package do
    [
      files: ["lib", "test", "config", "mix.exs"],
      maintainers: ["w1gz"],
      licenses: ["GPLv3"],
      links: %{"GitHub" => "https://github.com/w1gz/methal9k"}
    ]
  end
end
