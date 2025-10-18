defmodule Com.Atproto.Sync.NotifyOfUpdate do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Notify a crawling service of a recent update, and that crawling should resume. Intended use is after a gap between repo stream events caused the crawling service to disconnect. Does not require auth; implemented by Relay. DEPRECATED: just use com.atproto.sync.requestCrawl",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "hostname" => %{
                "description" =>
                  "Hostname of the current service (usually a PDS) that is notifying of update.",
                "type" => "string"
              }
            },
            "required" => ["hostname"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.sync.notifyOfUpdate",
    "lexicon" => 1
  })
end