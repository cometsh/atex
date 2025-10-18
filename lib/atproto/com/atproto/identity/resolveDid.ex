defmodule Com.Atproto.Identity.ResolveDid do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Resolves DID to DID document. Does not bi-directionally verify handle.",
        "errors" => [
          %{
            "description" => "The DID resolution process confirmed that there is no current DID.",
            "name" => "DidNotFound"
          },
          %{
            "description" => "The DID previously existed, but has been deactivated.",
            "name" => "DidDeactivated"
          }
        ],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "didDoc" => %{
                "description" => "The complete DID document for the identity.",
                "type" => "unknown"
              }
            },
            "required" => ["didDoc"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "did" => %{
              "description" => "DID to resolve.",
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
    "id" => "com.atproto.identity.resolveDid",
    "lexicon" => 1
  })
end