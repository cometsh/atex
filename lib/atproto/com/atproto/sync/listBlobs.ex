defmodule Com.Atproto.Sync.ListBlobs do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "List blob CIDs for an account, since some repo revision. Does not require auth; implemented by PDS.",
        "errors" => [
          %{"name" => "RepoNotFound"},
          %{"name" => "RepoTakendown"},
          %{"name" => "RepoSuspended"},
          %{"name" => "RepoDeactivated"}
        ],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "cids" => %{
                "items" => %{"format" => "cid", "type" => "string"},
                "type" => "array"
              },
              "cursor" => %{"type" => "string"}
            },
            "required" => ["cids"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "cursor" => %{"type" => "string"},
            "did" => %{
              "description" => "The DID of the repo.",
              "format" => "did",
              "type" => "string"
            },
            "limit" => %{
              "default" => 500,
              "maximum" => 1000,
              "minimum" => 1,
              "type" => "integer"
            },
            "since" => %{
              "description" => "Optional revision of the repo to list blobs since.",
              "format" => "tid",
              "type" => "string"
            }
          },
          "required" => ["did"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.sync.listBlobs",
    "lexicon" => 1
  })
end