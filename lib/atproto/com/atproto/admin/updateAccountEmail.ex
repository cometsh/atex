defmodule Com.Atproto.Admin.UpdateAccountEmail do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Administrative action to update an account's email.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "account" => %{
                "description" => "The handle or DID of the repo.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "email" => %{"type" => "string"}
            },
            "required" => ["account", "email"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.admin.updateAccountEmail",
    "lexicon" => 1
  })
end