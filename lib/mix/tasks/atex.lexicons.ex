defmodule Mix.Tasks.Atex.Lexicons do
  @moduledoc """
  Generate Elixir modules from AT Protocol lexicons, which can then be used to
  validate data at runtime.

  AT Protocol lexicons are JSON files that define parts of the AT Protocol data
  model. This task processes these lexicon files and generates corresponding
  Elixir modules.

  ## Usage

      mix atex.lexicons [OPTIONS] [PATHS]

  ## Arguments

  - `PATHS` - List of lexicon files to process. Also supports standard glob
    syntax for reading many lexicons at once.

  ## Options

  - `-o`/`--output` - Output directory for generated modules (default:
  `lib/atproto`)

  ## Examples

  Process all JSON files in the lexicons directory:

      mix atex.lexicons lexicons/**/*.json

  Process specific lexicon files:

      mix atex.lexicons lexicons/com/atproto/repo/*.json lexicons/app/bsky/actor/profile.json

  Generate modules to a custom output directory:

      mix atex.lexicons lexicons/**/*.json --output lib/my_atproto
  """
  @shortdoc "Generate Elixir modules from AT Protocol lexicons."

  use Mix.Task
  require EEx

  @switches [output: :string]
  @aliases [o: :output]
  @template_path Path.expand("../../../priv/templates/lexicon.eex", __DIR__)

  @impl Mix.Task
  def run(args) do
    {options, globs} = OptionParser.parse!(args, switches: @switches, aliases: @aliases)

    output = Keyword.get(options, :output, "lib/atproto")
    paths = Enum.flat_map(globs, &Path.wildcard/1)

    if length(paths) == 0 do
      Mix.shell().error("No valid search paths have been provided, aborting.")
    else
      Mix.shell().info("Generating modules for lexicons into #{output}")

      Enum.each(paths, fn path ->
        Mix.shell().info("- #{path}")
        generate(path, output)
      end)
    end
  end

  # TODO: validate schema?
  defp generate(input, output) do
    lexicon =
      input
      |> File.read!()
      |> JSON.decode!()

    if not is_binary(lexicon["id"]) do
      raise ArgumentError, message: "Malformed lexicon: does not have an `id` field."
    end

    code = lexicon |> template() |> Code.format_string!() |> Enum.join("")

    file_path =
      lexicon["id"]
      |> String.split(".")
      |> Enum.join("/")
      |> then(&(&1 <> ".ex"))
      |> then(&Path.join(output, &1))

    file_path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(file_path, code)
  end

  EEx.function_from_file(:defp, :template, @template_path, [:lexicon])
end
