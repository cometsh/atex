defmodule Sh.Comet.V0.Feed.Defs do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "buyLink" => %{
        "description" => "Indicate the link leads to a purchase page for the track.",
        "type" => "token"
      },
      "downloadLink" => %{
        "description" => "Indicate the link leads to a free download for the track.",
        "type" => "token"
      },
      "link" => %{
        "description" =>
          "Link for the track. Usually to acquire it in some way, e.g. via free download or purchase. | TODO: multiple links?",
        "properties" => %{
          "type" => %{
            "knownValues" => [
              "sh.comet.v0.feed.defs#downloadLink",
              "sh.comet.v0.feed.defs#buyLink"
            ],
            "type" => "string"
          },
          "value" => %{"format" => "uri", "type" => "string"}
        },
        "required" => ["type", "value"],
        "type" => "object"
      },
      "viewerState" => %{
        "description" =>
          "Metadata about the requesting account's relationship with the subject content. Only has meaningful content for authed requests.",
        "properties" => %{
          "featured" => %{"type" => "boolean"},
          "like" => %{"format" => "at-uri", "type" => "string"},
          "repost" => %{"format" => "at-uri", "type" => "string"}
        },
        "type" => "object"
      }
    },
    "id" => "sh.comet.v0.feed.defs",
    "lexicon" => 1
  })
end
