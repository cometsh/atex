defmodule Com.Atproto.Identity.SignPlcOperation do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Signs a PLC operation to update some value(s) in the requesting DID's document.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "alsoKnownAs" => %{
                "items" => %{"type" => "string"},
                "type" => "array"
              },
              "rotationKeys" => %{
                "items" => %{"type" => "string"},
                "type" => "array"
              },
              "services" => %{"type" => "unknown"},
              "token" => %{
                "description" =>
                  "A token received through com.atproto.identity.requestPlcOperationSignature",
                "type" => "string"
              },
              "verificationMethods" => %{"type" => "unknown"}
            },
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "operation" => %{
                "description" => "A signed DID PLC operation.",
                "type" => "unknown"
              }
            },
            "required" => ["operation"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.identity.signPlcOperation",
    "lexicon" => 1
  })
end