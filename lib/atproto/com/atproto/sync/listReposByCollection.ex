defmodule Com.Atproto.Sync.ListReposByCollection do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Enumerates all the DIDs which have records with the given collection NSID.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "repos" => %{
                "items" => %{"ref" => "#repo", "type" => "ref"},
                "type" => "array"
              }
            },
            "required" => ["repos"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "collection" => %{"format" => "nsid", "type" => "string"},
            "cursor" => %{"type" => "string"},
            "limit" => %{
              "default" => 500,
              "description" =>
                "Maximum size of response set. Recommend setting a large maximum (1000+) when enumerating large DID lists.",
              "maximum" => 2000,
              "minimum" => 1,
              "type" => "integer"
            }
          },
          "required" => ["collection"],
          "type" => "params"
        },
        "type" => "query"
      },
      "repo" => %{
        "properties" => %{"did" => %{"format" => "did", "type" => "string"}},
        "required" => ["did"],
        "type" => "object"
      }
    },
    "id" => "com.atproto.sync.listReposByCollection",
    "lexicon" => 1
  })
end