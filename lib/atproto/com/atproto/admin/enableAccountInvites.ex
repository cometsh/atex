defmodule Com.Atproto.Admin.EnableAccountInvites do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Re-enable an account's ability to receive invite codes.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "account" => %{"format" => "did", "type" => "string"},
              "note" => %{
                "description" => "Optional reason for enabled invites.",
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
    "id" => "com.atproto.admin.enableAccountInvites",
    "lexicon" => 1
  })
end