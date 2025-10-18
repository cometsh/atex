defmodule Com.Atproto.Identity.RefreshIdentity do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Request that the server re-resolve an identity (DID and handle). The server may ignore this request, or require authentication, depending on the role, implementation, and policy of the server.",
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
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "identifier" => %{"format" => "at-identifier", "type" => "string"}
            },
            "required" => ["identifier"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "ref" => "com.atproto.identity.defs#identityInfo",
            "type" => "ref"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.identity.refreshIdentity",
    "lexicon" => 1
  })
end