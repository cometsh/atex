defmodule Com.Atproto.Admin.Defs do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "accountView" => %{
        "properties" => %{
          "deactivatedAt" => %{"format" => "datetime", "type" => "string"},
          "did" => %{"format" => "did", "type" => "string"},
          "email" => %{"type" => "string"},
          "emailConfirmedAt" => %{"format" => "datetime", "type" => "string"},
          "handle" => %{"format" => "handle", "type" => "string"},
          "indexedAt" => %{"format" => "datetime", "type" => "string"},
          "inviteNote" => %{"type" => "string"},
          "invitedBy" => %{
            "ref" => "com.atproto.server.defs#inviteCode",
            "type" => "ref"
          },
          "invites" => %{
            "items" => %{
              "ref" => "com.atproto.server.defs#inviteCode",
              "type" => "ref"
            },
            "type" => "array"
          },
          "invitesDisabled" => %{"type" => "boolean"},
          "relatedRecords" => %{
            "items" => %{"type" => "unknown"},
            "type" => "array"
          },
          "threatSignatures" => %{
            "items" => %{"ref" => "#threatSignature", "type" => "ref"},
            "type" => "array"
          }
        },
        "required" => ["did", "handle", "indexedAt"],
        "type" => "object"
      },
      "repoBlobRef" => %{
        "properties" => %{
          "cid" => %{"format" => "cid", "type" => "string"},
          "did" => %{"format" => "did", "type" => "string"},
          "recordUri" => %{"format" => "at-uri", "type" => "string"}
        },
        "required" => ["did", "cid"],
        "type" => "object"
      },
      "repoRef" => %{
        "properties" => %{"did" => %{"format" => "did", "type" => "string"}},
        "required" => ["did"],
        "type" => "object"
      },
      "statusAttr" => %{
        "properties" => %{
          "applied" => %{"type" => "boolean"},
          "ref" => %{"type" => "string"}
        },
        "required" => ["applied"],
        "type" => "object"
      },
      "threatSignature" => %{
        "properties" => %{
          "property" => %{"type" => "string"},
          "value" => %{"type" => "string"}
        },
        "required" => ["property", "value"],
        "type" => "object"
      }
    },
    "id" => "com.atproto.admin.defs",
    "lexicon" => 1
  })
end