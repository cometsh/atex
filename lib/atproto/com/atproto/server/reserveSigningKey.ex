defmodule Com.Atproto.Server.ReserveSigningKey do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Reserve a repo signing key, for use with account creation. Necessary so that a DID PLC update operation can be constructed during an account migraiton. Public and does not require auth; implemented by PDS. NOTE: this endpoint may change when full account migration is implemented.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "did" => %{
                "description" => "The DID to reserve a key for.",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "signingKey" => %{
                "description" =>
                  "The public key for the reserved signing key, in did:key serialization.",
                "type" => "string"
              }
            },
            "required" => ["signingKey"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.reserveSigningKey",
    "lexicon" => 1
  })
end