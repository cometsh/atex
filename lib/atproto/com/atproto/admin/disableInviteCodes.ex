defmodule Com.Atproto.Admin.DisableInviteCodes do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Disable some set of codes and/or all codes associated with a set of users.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "accounts" => %{"items" => %{"type" => "string"}, "type" => "array"},
              "codes" => %{"items" => %{"type" => "string"}, "type" => "array"}
            },
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.admin.disableInviteCodes",
    "lexicon" => 1
  })
end