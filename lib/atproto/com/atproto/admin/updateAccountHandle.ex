defmodule Com.Atproto.Admin.UpdateAccountHandle do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Administrative action to update an account's handle.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "did" => %{"format" => "did", "type" => "string"},
              "handle" => %{"format" => "handle", "type" => "string"}
            },
            "required" => ["did", "handle"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.admin.updateAccountHandle",
    "lexicon" => 1
  })
end