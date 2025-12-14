defmodule Com.Atproto.Server.CreateInviteCode do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Create an invite code.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "forAccount" => %{"format" => "did", "type" => "string"},
              "useCount" => %{"type" => "integer"}
            },
            "required" => ["useCount"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"code" => %{"type" => "string"}},
            "required" => ["code"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.createInviteCode",
    "lexicon" => 1
  })
end