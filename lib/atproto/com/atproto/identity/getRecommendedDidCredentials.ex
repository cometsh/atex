defmodule Com.Atproto.Identity.GetRecommendedDidCredentials do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Describe the credentials that should be included in the DID doc of an account that is migrating to this service.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "alsoKnownAs" => %{
                "items" => %{"type" => "string"},
                "type" => "array"
              },
              "rotationKeys" => %{
                "description" =>
                  "Recommended rotation keys for PLC dids. Should be undefined (or ignored) for did:webs.",
                "items" => %{"type" => "string"},
                "type" => "array"
              },
              "services" => %{"type" => "unknown"},
              "verificationMethods" => %{"type" => "unknown"}
            },
            "type" => "object"
          }
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.identity.getRecommendedDidCredentials",
    "lexicon" => 1
  })
end