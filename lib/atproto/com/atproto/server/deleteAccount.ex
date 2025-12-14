defmodule Com.Atproto.Server.DeleteAccount do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Delete an actor's account with a token and password. Can only be called after requesting a deletion token. Requires auth.",
        "errors" => [%{"name" => "ExpiredToken"}, %{"name" => "InvalidToken"}],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "did" => %{"format" => "did", "type" => "string"},
              "password" => %{"type" => "string"},
              "token" => %{"type" => "string"}
            },
            "required" => ["did", "password", "token"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.deleteAccount",
    "lexicon" => 1
  })
end