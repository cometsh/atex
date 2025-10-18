defmodule Com.Atproto.Server.GetServiceAuth do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Get a signed token on behalf of the requesting DID for the requested service.",
        "errors" => [
          %{
            "description" =>
              "Indicates that the requested expiration date is not a valid. May be in the past or may be reliant on the requested scopes.",
            "name" => "BadExpiration"
          }
        ],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"token" => %{"type" => "string"}},
            "required" => ["token"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "aud" => %{
              "description" =>
                "The DID of the service that the token will be used to authenticate with",
              "format" => "did",
              "type" => "string"
            },
            "exp" => %{
              "description" =>
                "The time in Unix Epoch seconds that the JWT expires. Defaults to 60 seconds in the future. The service may enforce certain time bounds on tokens depending on the requested scope.",
              "type" => "integer"
            },
            "lxm" => %{
              "description" => "Lexicon (XRPC) method to bind the requested token to",
              "format" => "nsid",
              "type" => "string"
            }
          },
          "required" => ["aud"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.server.getServiceAuth",
    "lexicon" => 1
  })
end