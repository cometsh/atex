defmodule Com.Atproto.Identity.RequestPlcOperationSignature do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Request an email with a code to in order to request a signed PLC operation. Requires Auth.",
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.identity.requestPlcOperationSignature",
    "lexicon" => 1
  })
end