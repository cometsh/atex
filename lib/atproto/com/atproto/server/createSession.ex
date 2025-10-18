defmodule Com.Atproto.Server.CreateSession do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Create an authentication session.",
        "errors" => [
          %{"name" => "AccountTakedown"},
          %{"name" => "AuthFactorTokenRequired"}
        ],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "allowTakendown" => %{
                "description" =>
                  "When true, instead of throwing error for takendown accounts, a valid response with a narrow scoped token will be returned",
                "type" => "boolean"
              },
              "authFactorToken" => %{"type" => "string"},
              "identifier" => %{
                "description" =>
                  "Handle or other identifier supported by the server for the authenticating user.",
                "type" => "string"
              },
              "password" => %{"type" => "string"}
            },
            "required" => ["identifier", "password"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "accessJwt" => %{"type" => "string"},
              "active" => %{"type" => "boolean"},
              "did" => %{"format" => "did", "type" => "string"},
              "didDoc" => %{"type" => "unknown"},
              "email" => %{"type" => "string"},
              "emailAuthFactor" => %{"type" => "boolean"},
              "emailConfirmed" => %{"type" => "boolean"},
              "handle" => %{"format" => "handle", "type" => "string"},
              "refreshJwt" => %{"type" => "string"},
              "status" => %{
                "description" =>
                  "If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.",
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
    "id" => "com.atproto.server.createSession",
    "lexicon" => 1
  })
end