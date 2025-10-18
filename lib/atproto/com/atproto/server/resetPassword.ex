defmodule Com.Atproto.Server.ResetPassword do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Reset a user account password using a token.",
        "errors" => [%{"name" => "ExpiredToken"}, %{"name" => "InvalidToken"}],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "password" => %{"type" => "string"},
              "token" => %{"type" => "string"}
            },
            "required" => ["token", "password"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.resetPassword",
    "lexicon" => 1
  })
end