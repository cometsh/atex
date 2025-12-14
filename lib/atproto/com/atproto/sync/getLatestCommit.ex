defmodule Com.Atproto.Sync.GetLatestCommit do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Get the current commit CID & revision of the specified repo. Does not require auth.",
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
              "cid" => %{"format" => "cid", "type" => "string"},
              "rev" => %{"format" => "tid", "type" => "string"}
            },
            "required" => ["cid", "rev"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "did" => %{
              "description" => "The DID of the repo.",
              "format" => "did",
              "type" => "string"
            }
          },
          "required" => ["did"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.sync.getLatestCommit",
    "lexicon" => 1
  })
end