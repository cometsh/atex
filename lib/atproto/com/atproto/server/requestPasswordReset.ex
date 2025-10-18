defmodule Com.Atproto.Server.RequestPasswordReset do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Initiate a user account password reset via email.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"email" => %{"type" => "string"}},
            "required" => ["email"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.requestPasswordReset",
    "lexicon" => 1
  })
end