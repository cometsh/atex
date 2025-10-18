defmodule Com.Atproto.Repo.ListRecords do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "List a range of records in a repository, matching a specific collection. Does not require auth.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "records" => %{
                "items" => %{"ref" => "#record", "type" => "ref"},
                "type" => "array"
              }
            },
            "required" => ["records"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "collection" => %{
              "description" => "The NSID of the record type.",
              "format" => "nsid",
              "type" => "string"
            },
            "cursor" => %{"type" => "string"},
            "limit" => %{
              "default" => 50,
              "description" => "The number of records to return.",
              "maximum" => 100,
              "minimum" => 1,
              "type" => "integer"
            },
            "repo" => %{
              "description" => "The handle or DID of the repo.",
              "format" => "at-identifier",
              "type" => "string"
            },
            "reverse" => %{
              "description" => "Flag to reverse the order of the returned records.",
              "type" => "boolean"
            }
          },
          "required" => ["repo", "collection"],
          "type" => "params"
        },
        "type" => "query"
      },
      "record" => %{
        "properties" => %{
          "cid" => %{"format" => "cid", "type" => "string"},
          "uri" => %{"format" => "at-uri", "type" => "string"},
          "value" => %{"type" => "unknown"}
        },
        "required" => ["uri", "cid", "value"],
        "type" => "object"
      }
    },
    "id" => "com.atproto.repo.listRecords",
    "lexicon" => 1
  })
end