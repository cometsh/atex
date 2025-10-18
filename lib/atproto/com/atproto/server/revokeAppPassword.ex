defmodule Com.Atproto.Server.RevokeAppPassword do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Revoke an App Password by name.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"name" => %{"type" => "string"}},
            "required" => ["name"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.revokeAppPassword",
    "lexicon" => 1
  })
end