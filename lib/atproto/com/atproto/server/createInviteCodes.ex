defmodule Com.Atproto.Server.CreateInviteCodes do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "accountCodes" => %{
        "properties" => %{
          "account" => %{"type" => "string"},
          "codes" => %{"items" => %{"type" => "string"}, "type" => "array"}
        },
        "required" => ["account", "codes"],
        "type" => "object"
      },
      "main" => %{
        "description" => "Create invite codes.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "codeCount" => %{"default" => 1, "type" => "integer"},
              "forAccounts" => %{
                "items" => %{"format" => "did", "type" => "string"},
                "type" => "array"
              },
              "useCount" => %{"type" => "integer"}
            },
            "required" => ["codeCount", "useCount"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "codes" => %{
                "items" => %{"ref" => "#accountCodes", "type" => "ref"},
                "type" => "array"
              }
            },
            "required" => ["codes"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.createInviteCodes",
    "lexicon" => 1
  })
end