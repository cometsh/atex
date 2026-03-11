defmodule Com.Example.UploadBlob do
  @moduledoc false
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "Accepts a raw binary body and stores it as a blob. The Content-Type header must be set to the MIME type of the uploaded data.",
        "errors" => [
          %{
            "description" =>
              "The Content-Type of the uploaded data is not an accepted image MIME type.",
            "name" => "InvalidMimeType"
          },
          %{
            "description" => "The uploaded blob exceeds the maximum permitted size.",
            "name" => "BlobTooLarge"
          }
        ],
        "input" => %{
          "description" =>
            "Raw binary content of the blob. Supported MIME types: image/jpeg, image/png, image/gif, image/webp.",
          "encoding" => "*/*"
        },
        "output" => %{
          "encoding" => "application/json",
          "schema" => %{
            "properties" => %{
              "blob" => %{
                "accept" => ["image/*"],
                "maxSize" => 1_000_000,
                "type" => "blob"
              }
            },
            "required" => ["blob"],
            "type" => "object"
          }
        },
        "type" => "procedure"
      }
    },
    "description" => "Upload a binary blob (e.g. an image) and receive a blob reference.",
    "id" => "com.example.uploadBlob",
    "lexicon" => 1
  })
end
