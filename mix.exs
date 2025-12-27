defmodule Atex.MixProject do
  use Mix.Project

  @version "0.6.0"
  @github "https://github.com/cometsh/atex"
  @tangled "https://tangled.sh/@comet.sh/atex"

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
      {:peri, "~> 0.6"},
      {:multiformats_ex, "~> 0.2"},
      {:recase, "~> 0.5"},
      {:req, "~> 0.5"},
      {:typedstruct, "~> 0.5"},
      {:ex_cldr, "~> 2.42"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false, warn_if_outdated: true},
      {:plug, "~> 1.18"},
      {:jason, "~> 1.4"},
      {:jose, "~> 1.11"},
      {:bandit, "~> 1.0", only: [:dev, :test]},
      {:con_cache, "~> 1.1"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @github, "Tangled" => @tangled}
    ]
  end

  defp docs do
    [
      extras: [
        LICENSE: [title: "License"],
        "README.md": [title: "Overview"],
        "CHANGELOG.md": [title: "Changelog"]
      ],
      main: "readme",
      source_url: @github,
      source_ref: "v#{@version}",
      formatters: ["html"],
      groups_for_modules: [
        "Data types": [Atex.AtURI, Atex.DID, Atex.Handle, Atex.NSID, Atex.TID],
        XRPC: ~r/^Atex\.XRPC/,
        OAuth: [Atex.Config.OAuth, Atex.OAuth, Atex.OAuth.Plug],
        Lexicons: ~r/^Atex\.Lexicon/,
        Identity: ~r/^Atex\.IdentityResolver/
      ]
    ]
  end
end
