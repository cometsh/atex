defmodule Com.Atproto.Sync.GetRecord do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Get data blocks needed to prove the existence or non-existence of record in the current version of repo. Does not require auth.",
        "errors" => [
          %{"name" => "RecordNotFound"},
          %{"name" => "RepoNotFound"},
          %{"name" => "RepoTakendown"},
          %{"name" => "RepoSuspended"},
          %{"name" => "RepoDeactivated"}
        ],
        "output" => %{"encoding" => "application/vnd.ipld.car"},
        "parameters" => %{
          "properties" => %{
            "collection" => %{"format" => "nsid", "type" => "string"},
            "did" => %{
              "description" => "The DID of the repo.",
              "format" => "did",
              "type" => "string"
            },
            "rkey" => %{
              "description" => "Record Key",
              "format" => "record-key",
              "type" => "string"
            }
          },
          "required" => ["did", "collection", "rkey"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.sync.getRecord",
    "lexicon" => 1
  })
end