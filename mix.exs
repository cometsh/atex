defmodule Atex.MixProject do
  use Mix.Project

  def project do
    [
      app: :atex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:typedstruct, "~> 0.5"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end
end
