defmodule Com.Atproto.Sync.GetHostStatus do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Returns information about a specified upstream host, as consumed by the server. Implemented by relays.",
        "errors" => [%{"name" => "HostNotFound"}],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "accountCount" => %{
                "description" =>
                  "Number of accounts on the server which are associated with the upstream host. Note that the upstream may actually have more accounts.",
                "type" => "integer"
              },
              "hostname" => %{"type" => "string"},
              "seq" => %{
                "description" =>
                  "Recent repo stream event sequence number. May be delayed from actual stream processing (eg, persisted cursor not in-memory cursor).",
                "type" => "integer"
              },
              "status" => %{
                "ref" => "com.atproto.sync.defs#hostStatus",
                "type" => "ref"
              }
            },
            "required" => ["hostname"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "hostname" => %{
              "description" => "Hostname of the host (eg, PDS or relay) being queried.",
              "type" => "string"
            }
          },
          "required" => ["hostname"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.sync.getHostStatus",
    "lexicon" => 1
  })
end