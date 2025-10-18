defmodule Com.Atproto.Server.GetAccountInviteCodes do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Get all invite codes for the current account. Requires auth.",
        "errors" => [%{"name" => "DuplicateCreate"}],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "codes" => %{
                "items" => %{
                  "ref" => "com.atproto.server.defs#inviteCode",
                  "type" => "ref"
                },
                "type" => "array"
              }
            },
            "required" => ["codes"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "createAvailable" => %{
              "default" => true,
              "description" =>
                "Controls whether any new 'earned' but not 'created' invites should be created.",
              "type" => "boolean"
            },
            "includeUsed" => %{"default" => true, "type" => "boolean"}
          },
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.server.getAccountInviteCodes",
    "lexicon" => 1
  })
end