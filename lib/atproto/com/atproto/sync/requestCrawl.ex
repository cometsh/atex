defmodule Com.Atproto.Sync.RequestCrawl do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.",
        "errors" => [%{"name" => "HostBanned"}],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "hostname" => %{
                "description" =>
                  "Hostname of the current service (eg, PDS) that is requesting to be crawled.",
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
    "id" => "com.atproto.sync.requestCrawl",
    "lexicon" => 1
  })
end