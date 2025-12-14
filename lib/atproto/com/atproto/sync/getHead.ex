defmodule Com.Atproto.Sync.GetHead do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "DEPRECATED - please use com.atproto.sync.getLatestCommit instead",
        "errors" => [%{"name" => "HeadNotFound"}],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"root" => %{"format" => "cid", "type" => "string"}},
            "required" => ["root"],
            "type" => "object"
          }
        },
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
    "id" => "com.atproto.sync.getHead",
    "lexicon" => 1
  })
end