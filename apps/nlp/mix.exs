defmodule Adapt.Mixfile do
  use Mix.Project

  def project do
    [app: :nlp,
     version: "0.0.1",
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
     mod: {NLP, []}]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.11.4"},
      {:erlport, git: "https://github.com/beano/erlport.git"},
      {:adapt, git: "https://github.com/MycroftAI/adapt.git", app: false}
    ]
  end

  defp description do
    """
    Parsing natural language
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
