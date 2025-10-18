defmodule Com.Atproto.Server.ListAppPasswords do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "appPassword" => %{
        "properties" => %{
          "createdAt" => %{"format" => "datetime", "type" => "string"},
          "name" => %{"type" => "string"},
          "privileged" => %{"type" => "boolean"}
        },
        "required" => ["name", "createdAt"],
        "type" => "object"
      },
      "main" => %{
        "description" => "List all App Passwords.",
        "errors" => [%{"name" => "AccountTakedown"}],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "passwords" => %{
                "items" => %{"ref" => "#appPassword", "type" => "ref"},
                "type" => "array"
              }
            },
            "required" => ["passwords"],
            "type" => "object"
          }
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.server.listAppPasswords",
    "lexicon" => 1
  })
end