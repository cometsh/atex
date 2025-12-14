defmodule Com.Atproto.Server.ConfirmEmail do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Confirm an email using a token from com.atproto.server.requestEmailConfirmation.",
        "errors" => [
          %{"name" => "AccountNotFound"},
          %{"name" => "ExpiredToken"},
          %{"name" => "InvalidToken"},
          %{"name" => "InvalidEmail"}
        ],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "email" => %{"type" => "string"},
              "token" => %{"type" => "string"}
            },
            "required" => ["email", "token"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.confirmEmail",
    "lexicon" => 1
  })
end