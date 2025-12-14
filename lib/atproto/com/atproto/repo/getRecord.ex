defmodule Com.Atproto.Repo.GetRecord do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Get a single record from a repository. Does not require auth.",
        "errors" => [%{"name" => "RecordNotFound"}],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "cid" => %{"format" => "cid", "type" => "string"},
              "uri" => %{"format" => "at-uri", "type" => "string"},
              "value" => %{"type" => "unknown"}
            },
            "required" => ["uri", "value"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "cid" => %{
              "description" =>
                "The CID of the version of the record. If not specified, then return the most recent version.",
              "format" => "cid",
              "type" => "string"
            },
            "collection" => %{
              "description" => "The NSID of the record collection.",
              "format" => "nsid",
              "type" => "string"
            },
            "repo" => %{
              "description" => "The handle or DID of the repo.",
              "format" => "at-identifier",
              "type" => "string"
            },
            "rkey" => %{
              "description" => "The Record Key.",
              "format" => "record-key",
              "type" => "string"
            }
          },
          "required" => ["repo", "collection", "rkey"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.repo.getRecord",
    "lexicon" => 1
  })
end