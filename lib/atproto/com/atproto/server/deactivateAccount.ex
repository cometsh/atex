defmodule Com.Atproto.Server.DeactivateAccount do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Deactivates a currently active account. Stops serving of repo, and future writes to repo until reactivated. Used to finalize account migration with the old host after the account has been activated on the new host.",
        "input" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "deleteAfter" => %{
                "description" =>
                  "A recommendation to server as to how long they should hold onto the deactivated account before deleting.",
                "format" => "datetime",
                "type" => "string"
              }
            },
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.server.deactivateAccount",
    "lexicon" => 1
  })
end