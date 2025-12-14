defmodule Com.Atproto.Sync.Defs do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "hostStatus" => %{
        "knownValues" => ["active", "idle", "offline", "throttled", "banned"],
        "type" => "string"
      }
    },
    "id" => "com.atproto.sync.defs",
    "lexicon" => 1
  })
end