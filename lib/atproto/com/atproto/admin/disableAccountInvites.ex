defmodule Com.Atproto.Admin.DisableAccountInvites do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Disable an account from receiving new invite codes, but does not invalidate existing codes.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "account" => %{"format" => "did", "type" => "string"},
              "note" => %{
                "description" => "Optional reason for disabled invites.",
                "type" => "string"
              }
            },
            "required" => ["account"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.admin.disableAccountInvites",
    "lexicon" => 1
  })
end