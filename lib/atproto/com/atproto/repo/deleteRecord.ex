defmodule Com.Atproto.Repo.DeleteRecord do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Delete a repository record, or ensure it doesn't exist. Requires auth, implemented by PDS.",
        "errors" => [%{"name" => "InvalidSwap"}],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "collection" => %{
                "description" => "The NSID of the record collection.",
                "format" => "nsid",
                "type" => "string"
              },
              "repo" => %{
                "description" => "The handle or DID of the repo (aka, current account).",
                "format" => "at-identifier",
                "type" => "string"
              },
              "rkey" => %{
                "description" => "The Record Key.",
                "format" => "record-key",
                "type" => "string"
              },
              "swapCommit" => %{
                "description" => "Compare and swap with the previous commit by CID.",
                "format" => "cid",
                "type" => "string"
              },
              "swapRecord" => %{
                "description" => "Compare and swap with the previous record by CID.",
                "format" => "cid",
                "type" => "string"
              }
            },
            "required" => ["repo", "collection", "rkey"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "commit" => %{
                "ref" => "com.atproto.repo.defs#commitMeta",
                "type" => "ref"
              }
            },
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.repo.deleteRecord",
    "lexicon" => 1
  })
end