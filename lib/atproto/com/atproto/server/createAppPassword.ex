defmodule Com.Atproto.Server.CreateAppPassword do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "appPassword" => %{
        "properties" => %{
          "createdAt" => %{"format" => "datetime", "type" => "string"},
          "name" => %{"type" => "string"},
          "password" => %{"type" => "string"},
          "privileged" => %{"type" => "boolean"}
        },
        "required" => ["name", "password", "createdAt"],
        "type" => "object"
      },
      "main" => %{
        "description" => "Create an App Password.",
        "errors" => [%{"name" => "AccountTakedown"}],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "name" => %{
                "description" => "A short name for the App Password, to help distinguish them.",
                "type" => "string"
              },
              "privileged" => %{
                "description" =>
                  "If an app password has 'privileged' access to possibly sensitive account state. Meant for use with trusted clients.",
                "type" => "boolean"
              }
            },
            "required" => ["name"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{"ref" => "#appPassword", "type" => "ref"}
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.createAppPassword",
    "lexicon" => 1
  })
end