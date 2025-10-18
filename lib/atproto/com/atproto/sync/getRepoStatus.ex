defmodule Com.Atproto.Sync.GetRepoStatus do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Get the hosting status for a repository, on this server. Expected to be implemented by PDS and Relay.",
        "errors" => [%{"name" => "RepoNotFound"}],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "active" => %{"type" => "boolean"},
              "did" => %{"format" => "did", "type" => "string"},
              "rev" => %{
                "description" => "Optional field, the current rev of the repo, if active=true",
                "format" => "tid",
                "type" => "string"
              },
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
            "required" => ["did", "active"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "did" => %{
              "description" => "The DID of the repo.",
              "format" => "did",
              "type" => "string"
            }
          },
          "required" => ["did"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.sync.getRepoStatus",
    "lexicon" => 1
  })
end