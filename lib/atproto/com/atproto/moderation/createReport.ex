defmodule Com.Atproto.Moderation.CreateReport do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Submit a moderation report regarding an atproto account or record. Implemented by moderation services (with PDS proxying), and requires auth.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "modTool" => %{"ref" => "#modTool", "type" => "ref"},
              "reason" => %{
                "description" => "Additional context about the content and violation.",
                "maxGraphemes" => 2000,
                "maxLength" => 20000,
                "type" => "string"
              },
              "reasonType" => %{
                "description" => "Indicates the broad category of violation the report is for.",
                "ref" => "com.atproto.moderation.defs#reasonType",
                "type" => "ref"
              },
              "subject" => %{
                "refs" => ["com.atproto.admin.defs#repoRef", "com.atproto.repo.strongRef"],
                "type" => "union"
              }
            },
            "required" => ["reasonType", "subject"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "id" => %{"type" => "integer"},
              "reason" => %{
                "maxGraphemes" => 2000,
                "maxLength" => 20000,
                "type" => "string"
              },
              "reasonType" => %{
                "ref" => "com.atproto.moderation.defs#reasonType",
                "type" => "ref"
              },
              "reportedBy" => %{"format" => "did", "type" => "string"},
              "subject" => %{
                "refs" => ["com.atproto.admin.defs#repoRef", "com.atproto.repo.strongRef"],
                "type" => "union"
              }
            },
            "required" => ["id", "reasonType", "subject", "reportedBy", "createdAt"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      },
      "modTool" => %{
        "description" => "Moderation tool information for tracing the source of the action",
        "properties" => %{
          "meta" => %{
            "description" => "Additional arbitrary metadata about the source",
            "type" => "unknown"
          },
          "name" => %{
            "description" =>
              "Name/identifier of the source (e.g., 'bsky-app/android', 'bsky-web/chrome')",
            "type" => "string"
          }
        },
        "required" => ["name"],
        "type" => "object"
      }
    },
    "id" => "com.atproto.moderation.createReport",
    "lexicon" => 1
  })
end