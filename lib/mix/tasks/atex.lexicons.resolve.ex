defmodule Mix.Tasks.Atex.Lexicons.Resolve do
  @moduledoc """
  Resolve published AT Protocol lexicons by NSID and write them to JSON files.

  Lexicon schemas are published as records in atproto repositories. This task
  resolves one or more NSIDs using DNS-based authority lookup (via
  `_lexicon.<authority>` TXT records) and fetches the schema directly from the
  authoritative PDS, then writes each schema to disk as a JSON file.

  See `Atex.Lexicon.Resolver` for programmatic usage.

  ## Usage

      mix atex.lexicons.resolve [OPTIONS] <NSID> [<NSID> ...]

  ## Arguments

  - `NSID` - One or more AT Protocol NSIDs to resolve.

  ## Options

  - `-o`/`--output` - Output directory for resolved lexicon JSON files
    (default: `lexicons`).

  ## Examples

  Resolve a single lexicon:

      mix atex.lexicons.resolve app.bsky.feed.post

  Resolve multiple lexicons into a custom directory:

      mix atex.lexicons.resolve --output priv/lexicons app.bsky.feed.post com.atproto.repo.createRecord
  """
  @shortdoc "Resolve published AT Protocol lexicons by NSID."

  use Mix.Task

  alias Atex.Lexicon.Resolver

  @switches [output: :string]
  @aliases [o: :output]

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {options, nsids} = OptionParser.parse!(args, switches: @switches, aliases: @aliases)

    output = Keyword.get(options, :output, "lexicons")

    if nsids == [] do
      Mix.shell().error("No NSIDs provided. Usage: mix atex.lexicons.resolve <NSID> [<NSID> ...]")
    else
      Mix.shell().info("Resolving #{length(nsids)} lexicon(s) into #{output}/")

      Enum.each(nsids, fn nsid ->
        Mix.shell().info("- Resolving #{nsid}...")

        case Resolver.resolve(nsid) do
          {:ok, lexicon} ->
            path = nsid_to_path(nsid, output)

            path
            |> Path.dirname()
            |> File.mkdir_p!()

            File.write!(path, Jason.encode!(lexicon, pretty: true))
            Mix.shell().info("  Written to #{path}")

          {:error, reason} ->
            Mix.shell().error("  Failed to resolve #{nsid}: #{inspect(reason)}")
        end
      end)
    end
  end

  @doc false
  @spec nsid_to_path(String.t(), String.t()) :: String.t()
  def nsid_to_path(nsid, output) do
    nsid
    |> String.split(".")
    |> Enum.join("/")
    |> then(&(&1 <> ".json"))
    |> then(&Path.join(output, &1))
  end
end
