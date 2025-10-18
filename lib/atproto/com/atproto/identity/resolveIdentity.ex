defmodule Com.Atproto.Identity.ResolveIdentity do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Resolves an identity (DID or Handle) to a full identity (DID document and verified handle).",
        "errors" => [
          %{
            "description" =>
              "The resolution process confirmed that the handle does not resolve to any DID.",
            "name" => "HandleNotFound"
          },
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
            "ref" => "com.atproto.identity.defs#identityInfo",
            "type" => "ref"
          }
        },
        "parameters" => %{
          "properties" => %{
            "identifier" => %{
              "description" => "Handle or DID to resolve.",
              "format" => "at-identifier",
              "type" => "string"
            }
          },
          "required" => ["identifier"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.identity.resolveIdentity",
    "lexicon" => 1
  })
end