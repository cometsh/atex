defmodule Com.Atproto.Admin.GetInviteCodes do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Get an admin view of invite codes.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "codes" => %{
                "items" => %{
                  "ref" => "com.atproto.server.defs#inviteCode",
                  "type" => "ref"
                },
                "type" => "array"
              },
              "cursor" => %{"type" => "string"}
            },
            "required" => ["codes"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "cursor" => %{"type" => "string"},
            "limit" => %{
              "default" => 100,
              "maximum" => 500,
              "minimum" => 1,
              "type" => "integer"
            },
            "sort" => %{
              "default" => "recent",
              "knownValues" => ["recent", "usage"],
              "type" => "string"
            }
          },
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.admin.getInviteCodes",
    "lexicon" => 1
  })
end