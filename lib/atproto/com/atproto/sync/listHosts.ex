defmodule Com.Atproto.Sync.ListHosts do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "host" => %{
        "properties" => %{
          "accountCount" => %{"type" => "integer"},
          "hostname" => %{
            "description" => "hostname of server; not a URL (no scheme)",
            "type" => "string"
          },
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
      },
      "main" => %{
        "description" =>
          "Enumerates upstream hosts (eg, PDS or relay instances) that this service consumes from. Implemented by relays.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "hosts" => %{
                "description" =>
                  "Sort order is not formally specified. Recommended order is by time host was first seen by the server, with oldest first.",
                "items" => %{"ref" => "#host", "type" => "ref"},
                "type" => "array"
              }
            },
            "required" => ["hosts"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "cursor" => %{"type" => "string"},
            "limit" => %{
              "default" => 200,
              "maximum" => 1000,
              "minimum" => 1,
              "type" => "integer"
            }
          },
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.sync.listHosts",
    "lexicon" => 1
  })
end