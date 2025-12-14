defmodule Com.Atproto.Sync.GetBlob do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.",
        "errors" => [
          %{"name" => "BlobNotFound"},
          %{"name" => "RepoNotFound"},
          %{"name" => "RepoTakendown"},
          %{"name" => "RepoSuspended"},
          %{"name" => "RepoDeactivated"}
        ],
        "output" => %{"encoding" => "*/*"},
        "parameters" => %{
          "properties" => %{
            "cid" => %{
              "description" => "The CID of the blob to fetch",
              "format" => "cid",
              "type" => "string"
            },
            "did" => %{
              "description" => "The DID of the account.",
              "format" => "did",
              "type" => "string"
            }
          },
          "required" => ["did", "cid"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.sync.getBlob",
    "lexicon" => 1
  })
end