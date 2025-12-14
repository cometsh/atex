defmodule Com.Atproto.Server.DeleteSession do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Delete the current session. Requires auth.",
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.deleteSession",
    "lexicon" => 1
  })
end