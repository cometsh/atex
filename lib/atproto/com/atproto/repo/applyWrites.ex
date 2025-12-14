defmodule Com.Atproto.Repo.ApplyWrites do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "create" => %{
        "description" => "Operation which creates a new record.",
        "properties" => %{
          "collection" => %{"format" => "nsid", "type" => "string"},
          "rkey" => %{
            "description" =>
              "NOTE: maxLength is redundant with record-key format. Keeping it temporarily to ensure backwards compatibility.",
            "format" => "record-key",
            "maxLength" => 512,
            "type" => "string"
          },
          "value" => %{"type" => "unknown"}
        },
        "required" => ["collection", "value"],
        "type" => "object"
      },
      "createResult" => %{
        "properties" => %{
          "cid" => %{"format" => "cid", "type" => "string"},
          "uri" => %{"format" => "at-uri", "type" => "string"},
          "validationStatus" => %{
            "knownValues" => ["valid", "unknown"],
            "type" => "string"
          }
        },
        "required" => ["uri", "cid"],
        "type" => "object"
      },
      "delete" => %{
        "description" => "Operation which deletes an existing record.",
        "properties" => %{
          "collection" => %{"format" => "nsid", "type" => "string"},
          "rkey" => %{"format" => "record-key", "type" => "string"}
        },
        "required" => ["collection", "rkey"],
        "type" => "object"
      },
      "deleteResult" => %{
        "properties" => %{},
        "required" => [],
        "type" => "object"
      },
      "main" => %{
        "description" =>
          "Apply a batch transaction of repository creates, updates, and deletes. Requires auth, implemented by PDS.",
        "errors" => [
          %{
            "description" =>
              "Indicates that the 'swapCommit' parameter did not match current commit.",
            "name" => "InvalidSwap"
          }
        ],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "repo" => %{
                "description" => "The handle or DID of the repo (aka, current account).",
                "format" => "at-identifier",
                "type" => "string"
              },
              "swapCommit" => %{
                "description" =>
                  "If provided, the entire operation will fail if the current repo commit CID does not match this value. Used to prevent conflicting repo mutations.",
                "format" => "cid",
                "type" => "string"
              },
              "validate" => %{
                "description" =>
                  "Can be set to 'false' to skip Lexicon schema validation of record data across all operations, 'true' to require it, or leave unset to validate only for known Lexicons.",
                "type" => "boolean"
              },
              "writes" => %{
                "items" => %{
                  "closed" => true,
                  "refs" => ["#create", "#update", "#delete"],
                  "type" => "union"
                },
                "type" => "array"
              }
            },
            "required" => ["repo", "writes"],
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
              },
              "results" => %{
                "items" => %{
                  "closed" => true,
                  "refs" => ["#createResult", "#updateResult", "#deleteResult"],
                  "type" => "union"
                },
                "type" => "array"
              }
            },
            "required" => [],
            "type" => "object"
          }
        },
        "type" => "procedure"
      },
      "update" => %{
        "description" => "Operation which updates an existing record.",
        "properties" => %{
          "collection" => %{"format" => "nsid", "type" => "string"},
          "rkey" => %{"format" => "record-key", "type" => "string"},
          "value" => %{"type" => "unknown"}
        },
        "required" => ["collection", "rkey", "value"],
        "type" => "object"
      },
      "updateResult" => %{
        "properties" => %{
          "cid" => %{"format" => "cid", "type" => "string"},
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
    "id" => "com.atproto.repo.applyWrites",
    "lexicon" => 1
  })
end