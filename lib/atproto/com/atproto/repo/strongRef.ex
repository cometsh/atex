defmodule Com.Atproto.Repo.StrongRef do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "properties" => %{
          "cid" => %{"format" => "cid", "type" => "string"},
          "uri" => %{"format" => "at-uri", "type" => "string"}
        },
        "required" => ["uri", "cid"],
        "type" => "object"
      }
    },
    "description" => "A URI with a content-hash fingerprint.",
    "id" => "com.atproto.repo.strongRef",
    "lexicon" => 1
  })
end