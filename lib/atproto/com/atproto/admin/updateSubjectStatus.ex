defmodule Com.Atproto.Admin.UpdateSubjectStatus do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Update the service-specific admin status of a subject (account, record, or blob).",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "deactivated" => %{
                "ref" => "com.atproto.admin.defs#statusAttr",
                "type" => "ref"
              },
              "subject" => %{
                "refs" => [
                  "com.atproto.admin.defs#repoRef",
                  "com.atproto.repo.strongRef",
                  "com.atproto.admin.defs#repoBlobRef"
                ],
                "type" => "union"
              },
              "takedown" => %{
                "ref" => "com.atproto.admin.defs#statusAttr",
                "type" => "ref"
              }
            },
            "required" => ["subject"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "subject" => %{
                "refs" => [
                  "com.atproto.admin.defs#repoRef",
                  "com.atproto.repo.strongRef",
                  "com.atproto.admin.defs#repoBlobRef"
                ],
                "type" => "union"
              },
              "takedown" => %{
                "ref" => "com.atproto.admin.defs#statusAttr",
                "type" => "ref"
              }
            },
            "required" => ["subject"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.admin.updateSubjectStatus",
    "lexicon" => 1
  })
end