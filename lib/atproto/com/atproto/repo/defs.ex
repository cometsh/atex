defmodule Com.Atproto.Repo.Defs do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "commitMeta" => %{
        "properties" => %{
          "cid" => %{"format" => "cid", "type" => "string"},
          "rev" => %{"format" => "tid", "type" => "string"}
        },
        "required" => ["cid", "rev"],
        "type" => "object"
      }
    },
    "id" => "com.atproto.repo.defs",
    "lexicon" => 1
  })
end