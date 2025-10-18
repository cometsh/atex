defmodule Com.Atproto.Server.GetSession do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Get information about the current auth session. Requires auth.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "active" => %{"type" => "boolean"},
              "did" => %{"format" => "did", "type" => "string"},
              "didDoc" => %{"type" => "unknown"},
              "email" => %{"type" => "string"},
              "emailAuthFactor" => %{"type" => "boolean"},
              "emailConfirmed" => %{"type" => "boolean"},
              "handle" => %{"format" => "handle", "type" => "string"},
              "status" => %{
                "description" =>
                  "If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.",
                "knownValues" => ["takendown", "suspended", "deactivated"],
                "type" => "string"
              }
            },
            "required" => ["handle", "did"],
            "type" => "object"
          }
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.server.getSession",
    "lexicon" => 1
  })
end