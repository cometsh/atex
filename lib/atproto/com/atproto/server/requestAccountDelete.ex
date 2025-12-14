defmodule Com.Atproto.Server.RequestAccountDelete do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Initiate a user account deletion via email.",
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.requestAccountDelete",
    "lexicon" => 1
  })
end