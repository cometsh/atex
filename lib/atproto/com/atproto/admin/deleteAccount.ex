defmodule Com.Atproto.Admin.DeleteAccount do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Delete a user account as an administrator.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"did" => %{"format" => "did", "type" => "string"}},
            "required" => ["did"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.admin.deleteAccount",
    "lexicon" => 1
  })
end