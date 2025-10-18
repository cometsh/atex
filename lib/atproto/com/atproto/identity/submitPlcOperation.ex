defmodule Com.Atproto.Identity.SubmitPlcOperation do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Validates a PLC operation to ensure that it doesn't violate a service's constraints or get the identity into a bad state, then submits it to the PLC registry",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"operation" => %{"type" => "unknown"}},
            "required" => ["operation"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.identity.submitPlcOperation",
    "lexicon" => 1
  })
end