defmodule Com.Atproto.Sync.GetRepo do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Download a repository export as CAR file. Optionally only a 'diff' since a previous revision. Does not require auth; implemented by PDS.",
        "errors" => [
          %{"name" => "RepoNotFound"},
          %{"name" => "RepoTakendown"},
          %{"name" => "RepoSuspended"},
          %{"name" => "RepoDeactivated"}
        ],
        "output" => %{"encoding" => "application/vnd.ipld.car"},
        "parameters" => %{
          "properties" => %{
            "did" => %{
              "description" => "The DID of the repo.",
              "format" => "did",
              "type" => "string"
            },
            "since" => %{
              "description" => "The revision ('rev') of the repo to create a diff from.",
              "format" => "tid",
              "type" => "string"
            }
          },
          "required" => ["did"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.sync.getRepo",
    "lexicon" => 1
  })
end