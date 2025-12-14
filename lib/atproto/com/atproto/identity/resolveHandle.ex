defmodule Com.Atproto.Identity.ResolveHandle do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Resolves an atproto handle (hostname) to a DID. Does not necessarily bi-directionally verify against the the DID document.",
        "errors" => [
          %{
            "description" =>
              "The resolution process confirmed that the handle does not resolve to any DID.",
            "name" => "HandleNotFound"
          }
        ],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"did" => %{"format" => "did", "type" => "string"}},
            "required" => ["did"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "handle" => %{
              "description" => "The handle to resolve.",
              "format" => "handle",
              "type" => "string"
            }
          },
          "required" => ["handle"],
          "type" => "params"
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.identity.resolveHandle",
    "lexicon" => 1
  })
end