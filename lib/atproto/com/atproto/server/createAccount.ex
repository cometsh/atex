defmodule Com.Atproto.Server.CreateAccount do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Create an account. Implemented by PDS.",
        "errors" => [
          %{"name" => "InvalidHandle"},
          %{"name" => "InvalidPassword"},
          %{"name" => "InvalidInviteCode"},
          %{"name" => "HandleNotAvailable"},
          %{"name" => "UnsupportedDomain"},
          %{"name" => "UnresolvableDid"},
          %{"name" => "IncompatibleDidDoc"}
        ],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "did" => %{
                "description" => "Pre-existing atproto DID, being imported to a new account.",
                "format" => "did",
                "type" => "string"
              },
              "email" => %{"type" => "string"},
              "handle" => %{
                "description" => "Requested handle for the account.",
                "format" => "handle",
                "type" => "string"
              },
              "inviteCode" => %{"type" => "string"},
              "password" => %{
                "description" =>
                  "Initial account password. May need to meet instance-specific password strength requirements.",
                "type" => "string"
              },
              "plcOp" => %{
                "description" =>
                  "A signed DID PLC operation to be submitted as part of importing an existing account to this instance. NOTE: this optional field may be updated when full account migration is implemented.",
                "type" => "unknown"
              },
              "recoveryKey" => %{
                "description" =>
                  "DID PLC rotation key (aka, recovery key) to be included in PLC creation operation.",
                "type" => "string"
              },
              "verificationCode" => %{"type" => "string"},
              "verificationPhone" => %{"type" => "string"}
            },
            "required" => ["handle"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "description" => "Account login session returned on successful account creation.",
            "properties" => %{
              "accessJwt" => %{"type" => "string"},
              "did" => %{
                "description" => "The DID of the new account.",
                "format" => "did",
                "type" => "string"
              },
              "didDoc" => %{
                "description" => "Complete DID document.",
                "type" => "unknown"
              },
              "handle" => %{"format" => "handle", "type" => "string"},
              "refreshJwt" => %{"type" => "string"}
            },
            "required" => ["accessJwt", "refreshJwt", "handle", "did"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.createAccount",
    "lexicon" => 1
  })
end