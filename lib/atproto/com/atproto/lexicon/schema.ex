defmodule Com.Atproto.Lexicon.Schema do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Representation of Lexicon schemas themselves, when published as atproto records. Note that the schema language is not defined in Lexicon; this meta schema currently only includes a single version field ('lexicon'). See the atproto specifications for description of the other expected top-level fields ('id', 'defs', etc).",
        "key" => "nsid",
        "record" => %{
          "properties" => %{
            "lexicon" => %{
              "description" =>
                "Indicates the 'version' of the Lexicon language. Must be '1' for the current atproto/Lexicon schema system.",
              "type" => "integer"
            }
          },
          "required" => ["lexicon"],
          "type" => "object"
        },
        "type" => "record"
      }
    },
    "id" => "com.atproto.lexicon.schema",
    "lexicon" => 1
  })
end