defmodule Sh.Comet.V0.Feed.Track do
  @moduledoc """
  The following `deflexicon` call should result in something similar to the following output:

      import Peri
      import Atex.Lexicon.Validators

      @type main() :: %{}

  """
  use Atex.Lexicon
  # import Atex.Lexicon
  # import Atex.Lexicon.Validators
  # import Peri

  # TODO: need an example with `nullable` fields to demonstrate how those are handled (and also the weird extra types in lexicon defs like union)

  @type main() :: %{
          required(:audio) => Atex.Lexicon.Validators.blob_t(),
          required(:title) => String.t(),
          required(:createdAt) => String.t(),
          # TODO: check if peri replaces with `nil` or omits them completely.
          optional(:description) => String.t(),
          optional(:descriptionFacets) => Sh.Comet.V0.Richtext.Facet.main(),
          optional(:explicit) => boolean(),
          optional(:image) => Atex.Lexicon.Validators.blob_t(),
          optional(:link) => Sh.Comet.V0.Feed.Defs.link(),
          optional(:releasedAt) => String.t(),
          optional(:tags) => list(String.t())
        }

  @type view() :: %{
          required(:uri) => String.t(),
          required(:cid) => String.t(),
          required(:author) => Sh.Comet.V0.Actor.Profile.viewFull(),
          required(:audio) => String.t(),
          required(:record) => main(),
          required(:indexedAt) => String.t(),
          optional(:image) => String.t(),
          optional(:commentCount) => integer(),
          optional(:likeCount) => integer(),
          optional(:playCount) => integer(),
          optional(:repostCount) => integer(),
          optional(:viewer) => Sh.Comet.V0.Feed.Defs.viewerState()
        }

  # Should probably be a separate validator for all rkey formats.
  # defschema :main_rkey, string(format: :tid)

  # defschema :main, %{
  #   audio: {:required, blob(accept: ["audio/ogg"], max_size: 100_000_000)},
  #   title: {:required, string(min_length: 1, max_length: 2560, max_graphemes: 256)},
  #   createdAt: {:required, string(format: :datetime)},
  #   description: string(max_length: 20000, max_graphemes: 2000),
  #   # This is `ref`
  #   descriptionFacets: Sh.Comet.V0.Richtext.Facet.get_schema(:main),
  #   explicit: :boolean,
  #   image: blob(accept: ["image/png", "image/jpeg"], max_size: 1_000_000),
  #   link: Sh.Comet.V0.Feed.Defs.get_schema(:link),
  #   releasedAt: string(format: :datetime),
  #   tags: array(string(max_graphemes: 64, max_length: 640), max_length: 8)
  # }

  # defschema :view, %{
  #   uri: {:required, string(format: :at_uri)},
  #   cid: {:required, string(format: :cid)},
  #   author: {:required, Sh.Comet.V0.Actor.Profile.get_schema(:viewFull)},
  #   audio: {:required, string(format: :uri)},
  #   record: {:required, get_schema(:main)},
  #   indexedAt: {:required, string(format: :datetime)},
  #   image: string(format: :uri),
  #   commentCount: :integer,
  #   likeCount: :integer,
  #   playCount: :integer,
  #   repostCount: :integer,
  #   viewer: Sh.Comet.V0.Feed.Defs.get_schema(:viewerState)
  # }

  deflexicon(%{
    "defs" => %{
      "main" => %{
        "description" =>
          "A Comet audio track. TODO: should probably have some sort of pre-calculated waveform, or have a query to get one from a blob?",
        "key" => "tid",
        "record" => %{
          "properties" => %{
            "audio" => %{
              "accept" => ["audio/ogg"],
              "description" =>
                "Audio of the track, ideally encoded as 96k Opus. Limited to 100mb.",
              "maxSize" => 100_000_000,
              "type" => "blob"
            },
            "createdAt" => %{
              "description" => "Timestamp for when the track entry was originally created.",
              "format" => "datetime",
              "type" => "string"
            },
            "description" => %{
              "description" => "Description of the track.",
              "maxGraphemes" => 2000,
              "maxLength" => 20000,
              "type" => "string"
            },
            "descriptionFacets" => %{
              "description" => "Annotations of the track's description.",
              "ref" => "sh.comet.v0.richtext.facet",
              "type" => "ref"
            },
            "explicit" => %{
              "description" =>
                "Whether the track contains explicit content that may objectionable to some people, usually swearing or adult themes.",
              "type" => "boolean"
            },
            "image" => %{
              "accept" => ["image/png", "image/jpeg"],
              "description" => "Image to be displayed representing the track.",
              "maxSize" => 1_000_000,
              "type" => "blob"
            },
            "link" => %{"ref" => "sh.comet.v0.feed.defs#link", "type" => "ref"},
            "releasedAt" => %{
              "description" =>
                "Timestamp for when the track was released. If in the future, may be used to implement pre-savable tracks.",
              "format" => "datetime",
              "type" => "string"
            },
            "tags" => %{
              "description" => "Hashtags for the track, usually for genres.",
              "items" => %{
                "maxGraphemes" => 64,
                "maxLength" => 640,
                "type" => "string"
              },
              "maxLength" => 8,
              "type" => "array"
            },
            "title" => %{
              "description" =>
                "Title of the track. Usually shouldn't include the creator's name.",
              "maxGraphemes" => 256,
              "maxLength" => 2560,
              "minLength" => 1,
              "type" => "string"
            }
          },
          "required" => ["audio", "title", "createdAt"],
          "type" => "object"
        },
        "type" => "record"
      },
      "view" => %{
        "properties" => %{
          "audio" => %{
            "description" =>
              "URL pointing to where the audio data for the track can be fetched. May be re-encoded from the original blob.",
            "format" => "uri",
            "type" => "string"
          },
          "author" => %{
            "ref" => "sh.comet.v0.actor.profile#viewFull",
            "type" => "ref"
          },
          "cid" => %{"format" => "cid", "type" => "string"},
          "commentCount" => %{"type" => "integer"},
          "image" => %{
            "description" => "URL pointing to where the image for the track can be fetched.",
            "format" => "uri",
            "type" => "string"
          },
          "indexedAt" => %{"format" => "datetime", "type" => "string"},
          "likeCount" => %{"type" => "integer"},
          "playCount" => %{"type" => "integer"},
          "record" => %{"ref" => "#main", "type" => "ref"},
          "repostCount" => %{"type" => "integer"},
          "uri" => %{"format" => "at-uri", "type" => "string"},
          "viewer" => %{
            "ref" => "sh.comet.v0.feed.defs#viewerState",
            "type" => "ref"
          }
        },
        "required" => ["uri", "cid", "author", "audio", "record", "indexedAt"],
        "type" => "object"
      }
    },
    "id" => "sh.comet.v0.feed.track",
    "lexicon" => 1
  })
end
