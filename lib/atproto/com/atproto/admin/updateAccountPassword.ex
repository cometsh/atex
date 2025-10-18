defmodule Com.Atproto.Admin.UpdateAccountPassword do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Update the password for a user account as an administrator.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "did" => %{"format" => "did", "type" => "string"},
              "password" => %{"type" => "string"}
            },
            "required" => ["did", "password"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.admin.updateAccountPassword",
    "lexicon" => 1
  })
end