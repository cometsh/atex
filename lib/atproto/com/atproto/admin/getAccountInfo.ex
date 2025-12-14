defmodule Com.Atproto.Admin.GetAccountInfo do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Get details about an account.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "ref" => "com.atproto.admin.defs#accountView",
            "type" => "ref"
          }
        },
        "parameters" => %{
          "properties" => %{"did" => %{"format" => "did", "type" => "string"}},
          "required" => ["did"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.admin.getAccountInfo",
    "lexicon" => 1
  })
end