defmodule Com.Atproto.Repo.DescribeRepo do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Get information about an account and repository, including the list of collections. Does not require auth.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "collections" => %{
                "description" =>
                  "List of all the collections (NSIDs) for which this repo contains at least one record.",
                "items" => %{"format" => "nsid", "type" => "string"},
                "type" => "array"
              },
              "did" => %{"format" => "did", "type" => "string"},
              "didDoc" => %{
                "description" => "The complete DID document for this account.",
                "type" => "unknown"
              },
              "handle" => %{"format" => "handle", "type" => "string"},
              "handleIsCorrect" => %{
                "description" =>
                  "Indicates if handle is currently valid (resolves bi-directionally)",
                "type" => "boolean"
              }
            },
            "required" => ["handle", "did", "didDoc", "collections", "handleIsCorrect"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "repo" => %{
              "description" => "The handle or DID of the repo.",
              "format" => "at-identifier",
              "type" => "string"
            }
          },
          "required" => ["repo"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.repo.describeRepo",
    "lexicon" => 1
  })
end