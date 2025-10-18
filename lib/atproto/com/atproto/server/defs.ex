defmodule Com.Atproto.Server.Defs do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "inviteCode" => %{
        "properties" => %{
          "available" => %{"type" => "integer"},
          "code" => %{"type" => "string"},
          "createdAt" => %{"format" => "datetime", "type" => "string"},
          "createdBy" => %{"type" => "string"},
          "disabled" => %{"type" => "boolean"},
          "forAccount" => %{"type" => "string"},
          "uses" => %{
            "items" => %{"ref" => "#inviteCodeUse", "type" => "ref"},
            "type" => "array"
          }
        },
        "required" => [
          "code",
          "available",
          "disabled",
          "forAccount",
          "createdBy",
          "createdAt",
          "uses"
        ],
        "type" => "object"
      },
      "inviteCodeUse" => %{
        "properties" => %{
          "usedAt" => %{"format" => "datetime", "type" => "string"},
          "usedBy" => %{"format" => "did", "type" => "string"}
        },
        "required" => ["usedBy", "usedAt"],
        "type" => "object"
      }
    },
    "id" => "com.atproto.server.defs",
    "lexicon" => 1
  })
end