defmodule Com.Atproto.Repo.ImportRepo do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.",
        "input" => %{"encoding" => "application/vnd.ipld.car"},
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.repo.importRepo",
    "lexicon" => 1
  })
end