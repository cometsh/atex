defmodule Com.Atproto.Server.DescribeServer do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "contact" => %{
        "properties" => %{"email" => %{"type" => "string"}},
        "type" => "object"
      },
      "links" => %{
        "properties" => %{
          "privacyPolicy" => %{"format" => "uri", "type" => "string"},
          "termsOfService" => %{"format" => "uri", "type" => "string"}
        },
        "type" => "object"
      },
      "main" => %{
        "description" =>
          "Describes the server's account creation requirements and capabilities. Implemented by PDS.",
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "availableUserDomains" => %{
                "description" => "List of domain suffixes that can be used in account handles.",
                "items" => %{"type" => "string"},
                "type" => "array"
              },
              "contact" => %{
                "description" => "Contact information",
                "ref" => "#contact",
                "type" => "ref"
              },
              "did" => %{"format" => "did", "type" => "string"},
              "inviteCodeRequired" => %{
                "description" =>
                  "If true, an invite code must be supplied to create an account on this instance.",
                "type" => "boolean"
              },
              "links" => %{
                "description" => "URLs of service policy documents.",
                "ref" => "#links",
                "type" => "ref"
              },
              "phoneVerificationRequired" => %{
                "description" =>
                  "If true, a phone verification token must be supplied to create an account on this instance.",
                "type" => "boolean"
              }
            },
            "required" => ["did", "availableUserDomains"],
            "type" => "object"
          }
        },
        "type" => "query"
      }
    },
    "id" => "com.atproto.server.describeServer",
    "lexicon" => 1
  })
end