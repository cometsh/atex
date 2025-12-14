defmodule Com.Atproto.Admin.SearchAccounts do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Get list of accounts that matches your search query.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "accounts" => %{
                "items" => %{
                  "ref" => "com.atproto.admin.defs#accountView",
                  "type" => "ref"
                },
                "type" => "array"
              },
              "cursor" => %{"type" => "string"}
            },
            "required" => ["accounts"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "cursor" => %{"type" => "string"},
            "email" => %{"type" => "string"},
            "limit" => %{
              "default" => 50,
              "maximum" => 100,
              "minimum" => 1,
              "type" => "integer"
            }
          },
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.admin.searchAccounts",
    "lexicon" => 1
  })
end