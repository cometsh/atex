defmodule Com.Atproto.Sync.GetCheckout do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "DEPRECATED - please use com.atproto.sync.getRepo instead",
        "output" => %{"encoding" => "application/vnd.ipld.car"},
        "parameters" => %{
          "properties" => %{
            "did" => %{
              "description" => "The DID of the repo.",
              "format" => "did",
              "type" => "string"
            }
          },
          "required" => ["did"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.sync.getCheckout",
    "lexicon" => 1
  })
end