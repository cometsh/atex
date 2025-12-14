defmodule Com.Atproto.Sync.ListRepos do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Enumerates all the DID, rev, and commit CID for all repos hosted by this service. Does not require auth; implemented by PDS and Relay.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "repos" => %{
                "items" => %{"ref" => "#repo", "type" => "ref"},
                "type" => "array"
              }
            },
            "required" => ["repos"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "cursor" => %{"type" => "string"},
            "limit" => %{
              "default" => 500,
              "maximum" => 1000,
              "minimum" => 1,
              "type" => "integer"
            }
          },
          "type" => "params"
        },
        "type" => "query"
      },
      "repo" => %{
        "properties" => %{
          "active" => %{"type" => "boolean"},
          "did" => %{"format" => "did", "type" => "string"},
          "head" => %{
            "description" => "Current repo commit CID",
            "format" => "cid",
            "type" => "string"
          },
          "rev" => %{"format" => "tid", "type" => "string"},
          "status" => %{
            "description" =>
              "If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.",
            "knownValues" => [
              "takendown",
              "suspended",
              "deleted",
              "deactivated",
              "desynchronized",
              "throttled"
            ],
            "type" => "string"
          }
        },
        "required" => ["did", "head", "rev"],
        "type" => "object"
      }
    },
    "id" => "com.atproto.sync.listRepos",
    "lexicon" => 1
  })
end