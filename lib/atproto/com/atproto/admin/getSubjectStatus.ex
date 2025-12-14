defmodule Com.Atproto.Admin.GetSubjectStatus do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Get the service-specific admin status of a subject (account, record, or blob).",
        "output" => %{
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
        "parameters" => %{
          "properties" => %{
            "blob" => %{"format" => "cid", "type" => "string"},
            "did" => %{"format" => "did", "type" => "string"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.admin.getSubjectStatus",
    "lexicon" => 1
  })
end