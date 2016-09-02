defmodule Methal9k.Mixfile do
  use Mix.Project

  def project do
    [apps_path: "apps",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.13.0"},
      {:credo, "~> 0.4.11", only: [:dev, :test]},
      {:dogma, "~> 0.1.7"},
      {:excheck, "~> 0.5.0", only: :test},
      {:triq, github: "krestenkrab/triq", only: :test},
    ]
  end
end
