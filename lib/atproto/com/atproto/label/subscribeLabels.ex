defmodule Com.Atproto.Label.SubscribeLabels do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "info" => %{
        "properties" => %{
          "message" => %{"type" => "string"},
          "name" => %{"knownValues" => ["OutdatedCursor"], "type" => "string"}
        },
        "required" => ["name"],
        "type" => "object"
      },
      "labels" => %{
        "properties" => %{
          "labels" => %{
            "items" => %{"ref" => "com.atproto.label.defs#label", "type" => "ref"},
            "type" => "array"
          },
          "seq" => %{"type" => "integer"}
        },
        "required" => ["seq", "labels"],
        "type" => "object"
      },
      "main" => %{
        "description" =>
          "Subscribe to stream of labels (and negations). Public endpoint implemented by mod services. Uses same sequencing scheme as repo event stream.",
        "errors" => [%{"name" => "FutureCursor"}],
        "message" => %{
          "schema" => %{"refs" => ["#labels", "#info"], "type" => "union"}
        },
        "parameters" => %{
          "properties" => %{
            "cursor" => %{
              "description" => "The last known event seq number to backfill from.",
              "type" => "integer"
            }
          },
          "type" => "params"
        },
        "type" => "subscription"
      }
    },
    "id" => "com.atproto.label.subscribeLabels",
    "lexicon" => 1
  })
end