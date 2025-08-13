defmodule Sh.Comet.V0.Richtext.Facet do
  use Atex.Lexicon

  deflexicon(%{
    "defs" => %{
      "byteSlice" => %{
        "description" =>
          "Specifies the sub-string range a facet feature applies to. Start index is inclusive, end index is exclusive. Indices are zero-indexed, counting bytes of the UTF-8 encoded text. NOTE: some languages, like Javascript, use UTF-16 or Unicode codepoints for string slice indexing; in these languages, convert to byte arrays before working with facets.",
        "properties" => %{
          "byteEnd" => %{"minimum" => 0, "type" => "integer"},
          "byteStart" => %{"minimum" => 0, "type" => "integer"}
        },
        "required" => ["byteStart", "byteEnd"],
        "type" => "object"
      },
      "link" => %{
        "description" =>
          "Facet feature for a URL. The text URL may have been simplified or truncated, but the facet reference should be a complete URL.",
        "properties" => %{"uri" => %{"format" => "uri", "type" => "string"}},
        "required" => ["uri"],
        "type" => "object"
      },
      "main" => %{
        "description" => "Annotation of a sub-string within rich text.",
        "properties" => %{
          "features" => %{
            "items" => %{
              "refs" => ["#mention", "#link", "#tag"],
              "type" => "union"
            },
            "type" => "array"
          },
          "index" => %{"ref" => "#byteSlice", "type" => "ref"}
        },
        "required" => ["index", "features"],
        "type" => "object"
      },
      "mention" => %{
        "description" =>
          "Facet feature for mention of another account. The text is usually a handle, including a '@' prefix, but the facet reference is a DID.",
        "properties" => %{"did" => %{"format" => "did", "type" => "string"}},
        "required" => ["did"],
        "type" => "object"
      },
      "tag" => %{
        "description" =>
          "Facet feature for a hashtag. The text usually includes a '#' prefix, but the facet reference should not (except in the case of 'double hash tags').",
        "properties" => %{
          "tag" => %{"maxGraphemes" => 64, "maxLength" => 640, "type" => "string"}
        },
        "required" => ["tag"],
        "type" => "object"
      },
      "timestamp" => %{
        "description" =>
          "Facet feature for a timestamp in a track. The text usually is in the format of 'hh:mm:ss' with the hour section being omitted if unnecessary.",
        "properties" => %{
          "timestamp" => %{
            "description" => "Reference time, in seconds.",
            "minimum" => 0,
            "type" => "integer"
          }
        },
        "type" => "object"
      }
    },
    "id" => "sh.comet.v0.richtext.facet",
    "lexicon" => 1
  })
end
