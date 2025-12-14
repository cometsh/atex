defmodule Com.Atproto.Sync.SubscribeRepos do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "account" => %{
        "description" =>
          "Represents a change to an account's status on a host (eg, PDS or Relay). The semantics of this event are that the status is at the host which emitted the event, not necessarily that at the currently active PDS. Eg, a Relay takedown would emit a takedown with active=false, even if the PDS is still active.",
        "properties" => %{
          "active" => %{
            "description" =>
              "Indicates that the account has a repository which can be fetched from the host that emitted this event.",
            "type" => "boolean"
          },
          "did" => %{"format" => "did", "type" => "string"},
          "seq" => %{"type" => "integer"},
          "status" => %{
            "description" =>
              "If active=false, this optional field indicates a reason for why the account is not active.",
            "knownValues" => [
              "takendown",
              "suspended",
              "deleted",
              "deactivated",
              "desynchronized",
              "throttled"
            ],
            "type" => "string"
          },
          "time" => %{"format" => "datetime", "type" => "string"}
        },
        "required" => ["seq", "did", "time", "active"],
        "type" => "object"
      },
      "commit" => %{
        "description" =>
          "Represents an update of repository state. Note that empty commits are allowed, which include no repo data changes, but an update to rev and signature.",
        "nullable" => ["since"],
        "properties" => %{
          "blobs" => %{
            "items" => %{
              "description" =>
                "DEPRECATED -- will soon always be empty. List of new blobs (by CID) referenced by records in this commit.",
              "type" => "cid-link"
            },
            "type" => "array"
          },
          "blocks" => %{
            "description" =>
              "CAR file containing relevant blocks, as a diff since the previous repo state. The commit must be included as a block, and the commit block CID must be the first entry in the CAR header 'roots' list.",
            "maxLength" => 2_000_000,
            "type" => "bytes"
          },
          "commit" => %{
            "description" => "Repo commit object CID.",
            "type" => "cid-link"
          },
          "ops" => %{
            "items" => %{
              "description" =>
                "List of repo mutation operations in this commit (eg, records created, updated, or deleted).",
              "ref" => "#repoOp",
              "type" => "ref"
            },
            "maxLength" => 200,
            "type" => "array"
          },
          "prevData" => %{
            "description" =>
              "The root CID of the MST tree for the previous commit from this repo (indicated by the 'since' revision field in this message). Corresponds to the 'data' field in the repo commit object. NOTE: this field is effectively required for the 'inductive' version of firehose.",
            "type" => "cid-link"
          },
          "rebase" => %{
            "description" => "DEPRECATED -- unused",
            "type" => "boolean"
          },
          "repo" => %{
            "description" =>
              "The repo this event comes from. Note that all other message types name this field 'did'.",
            "format" => "did",
            "type" => "string"
          },
          "rev" => %{
            "description" =>
              "The rev of the emitted commit. Note that this information is also in the commit object included in blocks, unless this is a tooBig event.",
            "format" => "tid",
            "type" => "string"
          },
          "seq" => %{
            "description" => "The stream sequence number of this message.",
            "type" => "integer"
          },
          "since" => %{
            "description" => "The rev of the last emitted commit from this repo (if any).",
            "format" => "tid",
            "type" => "string"
          },
          "time" => %{
            "description" => "Timestamp of when this message was originally broadcast.",
            "format" => "datetime",
            "type" => "string"
          },
          "tooBig" => %{
            "description" =>
              "DEPRECATED -- replaced by #sync event and data limits. Indicates that this commit contained too many ops, or data size was too large. Consumers will need to make a separate request to get missing data.",
            "type" => "boolean"
          }
        },
        "required" => [
          "seq",
          "rebase",
          "tooBig",
          "repo",
          "commit",
          "rev",
          "since",
          "blocks",
          "ops",
          "blobs",
          "time"
        ],
        "type" => "object"
      },
      "identity" => %{
        "description" =>
          "Represents a change to an account's identity. Could be an updated handle, signing key, or pds hosting endpoint. Serves as a prod to all downstream services to refresh their identity cache.",
        "properties" => %{
          "did" => %{"format" => "did", "type" => "string"},
          "handle" => %{
            "description" =>
              "The current handle for the account, or 'handle.invalid' if validation fails. This field is optional, might have been validated or passed-through from an upstream source. Semantics and behaviors for PDS vs Relay may evolve in the future; see atproto specs for more details.",
            "format" => "handle",
            "type" => "string"
          },
          "seq" => %{"type" => "integer"},
          "time" => %{"format" => "datetime", "type" => "string"}
        },
        "required" => ["seq", "did", "time"],
        "type" => "object"
      },
      "info" => %{
        "properties" => %{
          "message" => %{"type" => "string"},
          "name" => %{"knownValues" => ["OutdatedCursor"], "type" => "string"}
        },
        "required" => ["name"],
        "type" => "object"
      },
      "main" => %{
        "description" =>
          "Repository event stream, aka Firehose endpoint. Outputs repo commits with diff data, and identity update events, for all repositories on the current server. See the atproto specifications for details around stream sequencing, repo versioning, CAR diff format, and more. Public and does not require auth; implemented by PDS and Relay.",
        "errors" => [
          %{"name" => "FutureCursor"},
          %{
            "description" =>
              "If the consumer of the stream can not keep up with events, and a backlog gets too large, the server will drop the connection.",
            "name" => "ConsumerTooSlow"
          }
        ],
        "message" => %{
          "schema" => %{
            "refs" => ["#commit", "#sync", "#identity", "#account", "#info"],
            "type" => "union"
          }
        },
        "parameters" => %{
          "properties" => %{
            "cursor" => %{
              "description" => "The last known event seq number to backfill from.",
              "type" => "integer"
            }
          },
          "type" => "params"
        },
        "type" => "subscription"
      },
      "repoOp" => %{
        "description" => "A repo operation, ie a mutation of a single record.",
        "nullable" => ["cid"],
        "properties" => %{
          "action" => %{
            "knownValues" => ["create", "update", "delete"],
            "type" => "string"
          },
          "cid" => %{
            "description" => "For creates and updates, the new record CID. For deletions, null.",
            "type" => "cid-link"
          },
          "path" => %{"type" => "string"},
          "prev" => %{
            "description" =>
              "For updates and deletes, the previous record CID (required for inductive firehose). For creations, field should not be defined.",
            "type" => "cid-link"
          }
        },
        "required" => ["action", "path", "cid"],
        "type" => "object"
      },
      "sync" => %{
        "description" =>
          "Updates the repo to a new state, without necessarily including that state on the firehose. Used to recover from broken commit streams, data loss incidents, or in situations where upstream host does not know recent state of the repository.",
        "properties" => %{
          "blocks" => %{
            "description" =>
              "CAR file containing the commit, as a block. The CAR header must include the commit block CID as the first 'root'.",
            "maxLength" => 10000,
            "type" => "bytes"
          },
          "did" => %{
            "description" =>
              "The account this repo event corresponds to. Must match that in the commit object.",
            "format" => "did",
            "type" => "string"
          },
          "rev" => %{
            "description" =>
              "The rev of the commit. This value must match that in the commit object.",
            "type" => "string"
          },
          "seq" => %{
            "description" => "The stream sequence number of this message.",
            "type" => "integer"
          },
          "time" => %{
            "description" => "Timestamp of when this message was originally broadcast.",
            "format" => "datetime",
            "type" => "string"
          }
        },
        "required" => ["seq", "did", "blocks", "rev", "time"],
        "type" => "object"
      }
    },
    "id" => "com.atproto.sync.subscribeRepos",
    "lexicon" => 1
  })
end