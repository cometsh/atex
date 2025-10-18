defmodule Com.Atproto.Repo.CreateRecord do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Create a single new repository record. Requires auth, implemented by PDS.",
        "errors" => [
          %{
            "description" => "Indicates that 'swapCommit' didn't match current repo commit.",
            "name" => "InvalidSwap"
          }
        ],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "collection" => %{
                "description" => "The NSID of the record collection.",
                "format" => "nsid",
                "type" => "string"
              },
              "record" => %{
                "description" => "The record itself. Must contain a $type field.",
                "type" => "unknown"
              },
              "repo" => %{
                "description" => "The handle or DID of the repo (aka, current account).",
                "format" => "at-identifier",
                "type" => "string"
              },
              "rkey" => %{
                "description" => "The Record Key.",
                "format" => "record-key",
                "maxLength" => 512,
                "type" => "string"
              },
              "swapCommit" => %{
                "description" => "Compare and swap with the previous commit by CID.",
                "format" => "cid",
                "type" => "string"
              },
              "validate" => %{
                "description" =>
                  "Can be set to 'false' to skip Lexicon schema validation of record data, 'true' to require it, or leave unset to validate only for known Lexicons.",
                "type" => "boolean"
              }
            },
            "required" => ["repo", "collection", "record"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "cid" => %{"format" => "cid", "type" => "string"},
              "commit" => %{
                "ref" => "com.atproto.repo.defs#commitMeta",
                "type" => "ref"
              },
              "uri" => %{"format" => "at-uri", "type" => "string"},
              "validationStatus" => %{
                "knownValues" => ["valid", "unknown"],
                "type" => "string"
              }
            },
            "required" => ["uri", "cid"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.repo.createRecord",
    "lexicon" => 1
  })
end