defmodule Com.Example.CreatePost do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Creates a post record and returns its AT-URI and CID.",
        "errors" => [
          %{
            "description" => "The post body failed content validation.",
            "name" => "InvalidContent"
          }
        ],
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{"ref" => "#postInput", "type" => "ref"}
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "cid" => %{"format" => "cid", "type" => "string"},
              "uri" => %{"format" => "at-uri", "type" => "string"}
            },
            "required" => ["uri", "cid"],
            "type" => "object"
          }
        },
        "parameters" => %{
          "properties" => %{
            "validate" => %{
              "default" => true,
              "description" => "When false, skip Lexicon validation of the post body.",
              "type" => "boolean"
            }
          },
          "type" => "params"
        },
        "type" => "procedure"
      },
      "postInput" => %{
        "description" => "Input body for creating a post.",
        "properties" => %{
          "createdAt" => %{
            "description" =>
              "Client-supplied creation timestamp. Defaults to server time if omitted.",
            "format" => "datetime",
            "type" => "string"
          },
          "langs" => %{
            "description" => "BCP-47 language tags describing the content language(s).",
            "items" => %{"format" => "language", "type" => "string"},
            "maxLength" => 3,
            "type" => "array"
          },
          "text" => %{
            "description" => "The plain-text content of the post.",
            "maxGraphemes" => 300,
            "maxLength" => 3000,
            "type" => "string"
          }
        },
        "required" => ["text"],
        "type" => "object"
      }
    },
    "description" => "Create a new post in a user's repository.",
    "id" => "com.example.createPost",
    "lexicon" => 1
  })
end
