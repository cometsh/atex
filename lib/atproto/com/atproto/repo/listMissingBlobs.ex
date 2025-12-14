defmodule Com.Atproto.Repo.ListMissingBlobs do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Returns a list of missing blobs for the requesting account. Intended to be used in the account migration flow.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "blobs" => %{
                "items" => %{"ref" => "#recordBlob", "type" => "ref"},
                "type" => "array"
              },
              "cursor" => %{"type" => "string"}
            },
            "required" => ["blobs"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "cursor" => %{"type" => "string"},
            "limit" => %{
              "default" => 500,
              "maximum" => 1000,
              "minimum" => 1,
              "type" => "integer"
            }
          },
          "type" => "params"
        },
        "type" => "query"
      },
      "recordBlob" => %{
        "properties" => %{
          "cid" => %{"format" => "cid", "type" => "string"},
          "recordUri" => %{"format" => "at-uri", "type" => "string"}
        },
        "required" => ["cid", "recordUri"],
        "type" => "object"
      }
    },
    "id" => "com.atproto.repo.listMissingBlobs",
    "lexicon" => 1
  })
end