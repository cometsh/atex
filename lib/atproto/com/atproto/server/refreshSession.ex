defmodule Com.Atproto.Server.RefreshSession do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Refresh an authentication session. Requires auth using the 'refreshJwt' (not the 'accessJwt').",
        "errors" => [%{"name" => "AccountTakedown"}],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "accessJwt" => %{"type" => "string"},
              "active" => %{"type" => "boolean"},
              "did" => %{"format" => "did", "type" => "string"},
              "didDoc" => %{"type" => "unknown"},
              "handle" => %{"format" => "handle", "type" => "string"},
              "refreshJwt" => %{"type" => "string"},
              "status" => %{
                "description" =>
                  "Hosting status of the account. If not specified, then assume 'active'.",
                "knownValues" => ["takendown", "suspended", "deactivated"],
                "type" => "string"
              }
            },
            "required" => ["accessJwt", "refreshJwt", "handle", "did"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.refreshSession",
    "lexicon" => 1
  })
end