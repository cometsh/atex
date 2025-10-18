defmodule Com.Atproto.Server.UpdateEmail do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Update an account's email.",
        "errors" => [
          %{"name" => "ExpiredToken"},
          %{"name" => "InvalidToken"},
          %{"name" => "TokenRequired"}
        ],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "email" => %{"type" => "string"},
              "emailAuthFactor" => %{"type" => "boolean"},
              "token" => %{
                "description" =>
                  "Requires a token from com.atproto.sever.requestEmailUpdate if the account's email has been confirmed.",
                "type" => "string"
              }
            },
            "required" => ["email"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.updateEmail",
    "lexicon" => 1
  })
end