defmodule Com.Atproto.Identity.Defs do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "identityInfo" => %{
        "properties" => %{
          "did" => %{"format" => "did", "type" => "string"},
          "didDoc" => %{
            "description" => "The complete DID document for the identity.",
            "type" => "unknown"
          },
          "handle" => %{
            "description" =>
              "The validated handle of the account; or 'handle.invalid' if the handle did not bi-directionally match the DID document.",
            "format" => "handle",
            "type" => "string"
          }
        },
        "required" => ["did", "handle", "didDoc"],
        "type" => "object"
      }
    },
    "id" => "com.atproto.identity.defs",
    "lexicon" => 1
  })
end