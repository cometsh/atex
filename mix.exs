defmodule Atex.MixProject do
  use Mix.Project

  @version "0.9.1"
  @github "https://github.com/cometsh/atex"
  @tangled "https://tangled.org/@comet.sh/atex"

  def project do
    [
      app: :atex,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "atex",
      description: "A set of utilities for working with the AT Protocol in Elixir.",
      package: package(),
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:con_cache, "~> 1.1"},
      {:mutex, "~> 3.0"},
      {:dasl, "~> 0.1"},
      {:mst, "~> 0.1"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.3", only: :dev}
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
        "Data types": [Atex.AtURI, ~r/^Atex\.DID/, Atex.Handle, Atex.NSID, Atex.TID],
        Repository: ~r/^Atex\.Repo/,
        XRPC: ~r/^Atex\.XRPC/,
        PLC: [Atex.PLC],
        OAuth: [Atex.Config.OAuth, ~r/^Atex\.OAuth/],
        Identity: [Atex.Config.IdentityResolver, ~r/^Atex\.IdentityResolver/],
        Lexicons: ~r/^Atex\.Lexicon/,
        "Service Auth": ~r/^Atex\.ServiceAuth/,
        "Implementation details": [Atex.Base32Sortable, Atex.Peri]
      ]
    ]
  end
end
