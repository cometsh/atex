defmodule Com.Atproto.Server.ActivateAccount do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Activates a currently deactivated account. Used to finalize account migration after the account's repo is imported and identity is setup.",
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.activateAccount",
    "lexicon" => 1
  })
end