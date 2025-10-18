defmodule Com.Atproto.Sync.GetBlocks do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.",
        "errors" => [
          %{"name" => "BlockNotFound"},
          %{"name" => "RepoNotFound"},
          %{"name" => "RepoTakendown"},
          %{"name" => "RepoSuspended"},
          %{"name" => "RepoDeactivated"}
        ],
        "output" => %{"encoding" => "application/vnd.ipld.car"},
        "parameters" => %{
          "properties" => %{
            "cids" => %{
              "items" => %{"format" => "cid", "type" => "string"},
              "type" => "array"
            },
            "did" => %{
              "description" => "The DID of the repo.",
              "format" => "did",
              "type" => "string"
            }
          },
          "required" => ["did", "cids"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.sync.getBlocks",
    "lexicon" => 1
  })
end