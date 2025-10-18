defmodule Com.Atproto.Server.CheckAccountStatus do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Returns the status of an account, especially as pertaining to import or recovery. Can be called many times over the course of an account migration. Requires auth and can only be called pertaining to oneself.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "activated" => %{"type" => "boolean"},
              "expectedBlobs" => %{"type" => "integer"},
              "importedBlobs" => %{"type" => "integer"},
              "indexedRecords" => %{"type" => "integer"},
              "privateStateValues" => %{"type" => "integer"},
              "repoBlocks" => %{"type" => "integer"},
              "repoCommit" => %{"format" => "cid", "type" => "string"},
              "repoRev" => %{"type" => "string"},
              "validDid" => %{"type" => "boolean"}
            },
            "required" => [
              "activated",
              "validDid",
              "repoCommit",
              "repoRev",
              "repoBlocks",
              "indexedRecords",
              "privateStateValues",
              "expectedBlobs",
              "importedBlobs"
            ],
            "type" => "object"
          }
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.server.checkAccountStatus",
    "lexicon" => 1
  })
end