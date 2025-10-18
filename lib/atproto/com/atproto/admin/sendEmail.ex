defmodule Com.Atproto.Admin.SendEmail do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" => "Send email to a user's account email address.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "comment" => %{
                "description" =>
                  "Additional comment by the sender that won't be used in the email itself but helpful to provide more context for moderators/reviewers",
                "type" => "string"
              },
              "content" => %{"type" => "string"},
              "recipientDid" => %{"format" => "did", "type" => "string"},
              "senderDid" => %{"format" => "did", "type" => "string"},
              "subject" => %{"type" => "string"}
            },
            "required" => ["recipientDid", "content", "senderDid"],
            "type" => "object"
          }
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"sent" => %{"type" => "boolean"}},
            "required" => ["sent"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.admin.sendEmail",
    "lexicon" => 1
  })
end