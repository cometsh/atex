defmodule Sh.Comet.V0.Feed.GetActorTracks do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Get a list of an actor's tracks.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "tracks" => %{
                "items" => %{
                  "ref" => "sh.comet.v0.feed.track#view",
                  "type" => "ref"
                },
                "type" => "array"
              }
            },
            "required" => ["tracks"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "actor" => %{"format" => "at-identifier", "type" => "string"},
            "cursor" => %{"type" => "string"},
            "limit" => %{
              "default" => 50,
              "maximum" => 100,
              "minimum" => 1,
              "type" => "integer"
            }
          },
          "required" => ["actor"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "sh.comet.v0.feed.getActorTracks",
    "lexicon" => 1
  })
end
