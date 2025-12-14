defmodule Com.Atproto.Admin.UpdateAccountSigningKey do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Administrative action to update an account's signing key in their Did document.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "did" => %{"format" => "did", "type" => "string"},
              "signingKey" => %{
                "description" => "Did-key formatted public key",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["did", "signingKey"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.admin.updateAccountSigningKey",
    "lexicon" => 1
  })
end