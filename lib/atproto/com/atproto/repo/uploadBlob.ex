defmodule Com.Atproto.Repo.UploadBlob do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Upload a new blob, to be referenced from a repository record. The blob will be deleted if it is not referenced within a time window (eg, minutes). Blob restrictions (mimetype, size, etc) are enforced when the reference is created. Requires auth, implemented by PDS.",
        "input" => %{"encoding" => "*/*"},
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{"blob" => %{"type" => "blob"}},
            "required" => ["blob"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "id" => "com.atproto.repo.uploadBlob",
    "lexicon" => 1
  })
end