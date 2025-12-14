defmodule Com.Atproto.Label.QueryLabels do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Find labels relevant to the provided AT-URI patterns. Public endpoint for moderation services, though may return different or additional results with auth.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "labels" => %{
                "items" => %{
                  "ref" => "com.atproto.label.defs#label",
                  "type" => "ref"
                },
                "type" => "array"
              }
            },
            "required" => ["labels"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "cursor" => %{"type" => "string"},
            "limit" => %{
              "default" => 50,
              "maximum" => 250,
              "minimum" => 1,
              "type" => "integer"
            },
            "sources" => %{
              "description" => "Optional list of label sources (DIDs) to filter on.",
              "items" => %{"format" => "did", "type" => "string"},
              "type" => "array"
            },
            "uriPatterns" => %{
              "description" =>
                "List of AT URI patterns to match (boolean 'OR'). Each may be a prefix (ending with '*'; will match inclusive of the string leading to '*'), or a full URI.",
              "items" => %{"type" => "string"},
              "type" => "array"
            }
          },
          "required" => ["uriPatterns"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.label.queryLabels",
    "lexicon" => 1
  })
end