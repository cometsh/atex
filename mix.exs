defmodule Atex.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/cometsh/atex"

  def project do
    [
      app: :atex,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "atex",
      description: "A set of utilities for working with the AT Protocol in Elixir.",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Atex.Application, []}
    ]
  end

  defp deps do
    [
      {:peri, "~> 0.4"},
      {:multiformats_ex, "~> 0.2"},
      {:recase, "~> 0.5"},
      {:req, "~> 0.5"},
      {:typedstruct, "~> 0.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      extras: [
        LICENSE: [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
