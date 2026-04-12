defmodule Atex.NSIDTest do
  use ExUnit.Case, async: true

  import Atex.NSID, only: [sigil_NSID: 2]

  alias Atex.NSID

  # ---------------------------------------------------------------------------
  # NSID.new/1
  # ---------------------------------------------------------------------------

  describe "NSID.new/1" do
    test "parses a standard 4-part NSID" do
      assert {:ok, %NSID{authority: "app.bsky.feed", name: "post", fragment: nil}} =
               NSID.new("app.bsky.feed.post")
    end

    test "parses a minimal 3-segment NSID" do
      assert {:ok, %NSID{authority: "com.example", name: "record", fragment: nil}} =
               NSID.new("com.example.record")
    end

    test "parses an NSID with a fragment" do
      assert {:ok, %NSID{authority: "app.bsky.feed", name: "post", fragment: "view"}} =
               NSID.new("app.bsky.feed.post#view")
    end

    test "parses an NSID with numbers in authority segments" do
      assert {:ok, %NSID{authority: "sh.comet.v0", name: "feed", fragment: nil}} =
               NSID.new("sh.comet.v0.feed")
    end

    test "returns error for a plain string without dots" do
      assert {:error, :invalid_nsid} = NSID.new("invalid")
    end

    test "returns error for an empty string" do
      assert {:error, :invalid_nsid} = NSID.new("")
    end

    test "returns error for a string with invalid characters" do
      assert {:error, :invalid_nsid} = NSID.new("not.valid!")
    end

    test "returns error for a two-segment string (no name)" do
      assert {:error, :invalid_nsid} = NSID.new("com.example")
    end
  end

  # ---------------------------------------------------------------------------
  # NSID.new!/1
  # ---------------------------------------------------------------------------

  describe "NSID.new!/1" do
    test "returns the struct for a valid NSID" do
      assert %NSID{authority: "app.bsky.feed", name: "post"} = NSID.new!("app.bsky.feed.post")
    end

    test "raises ArgumentError for an invalid NSID" do
      assert_raise ArgumentError, ~r/invalid NSID/, fn ->
        NSID.new!("bad")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ~NSID sigil
  # ---------------------------------------------------------------------------

  describe "~NSID sigil" do
    test "constructs the correct struct" do
      assert %NSID{authority: "app.bsky.feed", name: "post", fragment: nil} =
               ~NSID"app.bsky.feed.post"
    end

    test "constructs the correct struct with a fragment" do
      assert %NSID{authority: "app.bsky.feed", name: "post", fragment: "view"} =
               ~NSID"app.bsky.feed.post#view"
    end
  end

  # ---------------------------------------------------------------------------
  # String.Chars / to_string
  # ---------------------------------------------------------------------------

  describe "String.Chars" do
    test "renders a plain NSID" do
      assert "app.bsky.feed.post" = to_string(~NSID"app.bsky.feed.post")
    end

    test "renders an NSID with a fragment" do
      assert "app.bsky.feed.post#view" = to_string(~NSID"app.bsky.feed.post#view")
    end

    test "interpolates correctly in a string" do
      nsid = ~NSID"app.bsky.feed.post"
      assert "type: app.bsky.feed.post" = "type: #{nsid}"
    end
  end

  # ---------------------------------------------------------------------------
  # NSID.match?/1
  # ---------------------------------------------------------------------------

  describe "NSID.match?/1" do
    test "returns true for a valid NSID" do
      assert NSID.match?("app.bsky.feed.post")
    end

    test "returns false for an invalid string" do
      refute NSID.match?("invalid")
    end

    test "returns false for a fragment-bearing string" do
      refute NSID.match?("app.bsky.feed.post#view")
    end
  end

  # ---------------------------------------------------------------------------
  # NSID.to_atom/2
  # ---------------------------------------------------------------------------

  describe "NSID.to_atom/2" do
    test "converts to a fully-qualified module atom by default" do
      assert App.Bsky.Feed.Post = NSID.to_atom(~NSID"app.bsky.feed.post")
    end

    test "converts without full qualification when false is passed" do
      result = NSID.to_atom(~NSID"app.bsky.feed.post", false)
      assert result == :"App.Bsky.Feed.Post"
    end

    test "ignores any fragment" do
      assert App.Bsky.Feed.Post = NSID.to_atom(~NSID"app.bsky.feed.post#view")
    end
  end

  # ---------------------------------------------------------------------------
  # NSID.to_atom_with_fragment/1
  # ---------------------------------------------------------------------------

  describe "NSID.to_atom_with_fragment/1" do
    test "returns {module, :main} for a plain NSID" do
      assert {App.Bsky.Feed.Post, :main} = NSID.to_atom_with_fragment(~NSID"app.bsky.feed.post")
    end

    test "returns {module, fragment_atom} when fragment is present" do
      assert {App.Bsky.Feed.Post, :view} =
               NSID.to_atom_with_fragment(~NSID"app.bsky.feed.post#view")
    end
  end

  # ---------------------------------------------------------------------------
  # NSID.expand_fragment_shorthand/2
  # ---------------------------------------------------------------------------

  describe "NSID.expand_fragment_shorthand/2" do
    test "expands a shorthand fragment" do
      assert "app.bsky.feed.post#view" =
               NSID.expand_fragment_shorthand(~NSID"app.bsky.feed.post", "#view")
    end

    test "passes through a fully-qualified NSID unchanged" do
      assert "com.example.other" =
               NSID.expand_fragment_shorthand(~NSID"app.bsky.feed.post", "com.example.other")
    end

    test "passes through a non-fragment string unchanged" do
      assert "main" = NSID.expand_fragment_shorthand(~NSID"app.bsky.feed.post", "main")
    end
  end

  # ---------------------------------------------------------------------------
  # NSID.canonical_name/1
  # ---------------------------------------------------------------------------

  describe "NSID.canonical_name/1" do
    test "returns the plain NSID when fragment is nil" do
      assert "app.bsky.feed.post" = NSID.canonical_name(~NSID"app.bsky.feed.post")
    end

    test "returns the plain NSID when fragment is \"main\"" do
      nsid = %NSID{authority: "app.bsky.feed", name: "post", fragment: "main"}
      assert "app.bsky.feed.post" = NSID.canonical_name(nsid)
    end

    test "returns nsid#fragment when fragment is non-main" do
      assert "app.bsky.feed.post#view" = NSID.canonical_name(~NSID"app.bsky.feed.post#view")
    end
  end

  # ---------------------------------------------------------------------------
  # NSID.authority_domain/1
  # ---------------------------------------------------------------------------

  describe "NSID.authority_domain/1" do
    test "converts a standard 4-part NSID" do
      assert "_lexicon.feed.bsky.app" = NSID.authority_domain(~NSID"app.bsky.feed.post")
    end

    test "matches the spec example" do
      assert "_lexicon.blogging.lab.dept.university.edu" =
               NSID.authority_domain(~NSID"edu.university.dept.lab.blogging.getBlogPost")
    end

    test "handles a minimal 3-segment NSID" do
      assert "_lexicon.example.com" = NSID.authority_domain(~NSID"com.example.record")
    end

    test "handles NSIDs with numbers in segments" do
      assert "_lexicon.v0.comet.sh" = NSID.authority_domain(~NSID"sh.comet.v0.feed")
    end
  end
end
