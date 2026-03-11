defmodule Com.Example.GetProfile do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Returns profile information for the specified account.",
        "errors" => [
          %{
            "description" => "No account exists for the given actor.",
            "name" => "AccountNotFound"
          }
        ],
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{"ref" => "#profileView", "type" => "ref"}
        },
        "parameters" => %{
          "properties" => %{
            "actor" => %{
              "description" => "The DID or handle of the account to fetch.",
              "format" => "at-identifier",
              "type" => "string"
            }
          },
          "required" => ["actor"],
          "type" => "params"
        },
        "type" => "query"
      },
      "profileView" => %{
        "description" => "A public view of a user profile.",
        "properties" => %{
          "avatar" => %{"format" => "uri", "type" => "string"},
          "createdAt" => %{"format" => "datetime", "type" => "string"},
          "description" => %{
            "maxGraphemes" => 256,
            "maxLength" => 2560,
            "type" => "string"
          },
          "did" => %{"format" => "did", "type" => "string"},
          "displayName" => %{
            "maxGraphemes" => 64,
            "maxLength" => 640,
            "type" => "string"
          },
          "handle" => %{"format" => "handle", "type" => "string"}
        },
        "required" => ["did", "handle"],
        "type" => "object"
      }
    },
    "description" => "Fetch a user profile by DID or handle.",
    "id" => "com.example.getProfile",
    "lexicon" => 1
  })
end
