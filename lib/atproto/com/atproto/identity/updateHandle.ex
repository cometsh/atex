defmodule Com.Atproto.Identity.UpdateHandle do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Updates the current account's handle. Verifies handle validity, and updates did:plc document if necessary. Implemented by PDS, and requires auth.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "handle" => %{
                "description" => "The new handle.",
                "format" => "handle",
                "type" => "string"
              }
            },
            "required" => ["handle"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.identity.updateHandle",
    "lexicon" => 1
  })
end