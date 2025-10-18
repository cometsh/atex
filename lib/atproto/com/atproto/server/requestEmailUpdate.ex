defmodule Com.Atproto.Server.RequestEmailUpdate do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Request a token in order to update email.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"tokenRequired" => %{"type" => "boolean"}},
            "required" => ["tokenRequired"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.requestEmailUpdate",
    "lexicon" => 1
  })
end