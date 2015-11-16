defmodule Hal.Mixfile do
  use Mix.Project

  def project do
    [app: :hal9k,
     version: "0.10.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.3-dev",
     description: description,
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :exirc],
     mod: {Hal, ["credz"]}]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.11.4"},
      {:exirc, "~> 0.11.0"},
      {:uuid, "~> 1.1.3"}
    ]
  end

  defp description do
    """
    IRC handler of methal9k
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
