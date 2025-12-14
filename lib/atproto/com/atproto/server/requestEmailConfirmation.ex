defmodule Com.Atproto.Server.RequestEmailConfirmation do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Request an email with a code to confirm ownership of email.",
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.requestEmailConfirmation",
    "lexicon" => 1
  })
end