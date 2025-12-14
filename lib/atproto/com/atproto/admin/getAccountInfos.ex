defmodule Com.Atproto.Admin.GetAccountInfos do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Get details about some accounts.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "infos" => %{
                "items" => %{
                  "ref" => "com.atproto.admin.defs#accountView",
                  "type" => "ref"
                },
                "type" => "array"
              }
            },
            "required" => ["infos"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "dids" => %{
              "items" => %{"format" => "did", "type" => "string"},
              "type" => "array"
            }
          },
          "required" => ["dids"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.admin.getAccountInfos",
    "lexicon" => 1
  })
end