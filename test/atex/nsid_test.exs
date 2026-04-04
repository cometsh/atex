defmodule Atex.NSIDTest do
  use ExUnit.Case, async: true

  alias Atex.NSID

  # ---------------------------------------------------------------------------
  # NSID.authority_domain/1
  # ---------------------------------------------------------------------------

  describe "NSID.authority_domain/1" do
    test "converts a standard 4-part NSID" do
      assert {:ok, "_lexicon.feed.bsky.app"} = NSID.authority_domain("app.bsky.feed.post")
    end

    test "matches the spec example" do
      assert {:ok, "_lexicon.blogging.lab.dept.university.edu"} =
               NSID.authority_domain("edu.university.dept.lab.blogging.getBlogPost")
    end

    test "handles a minimal 3-segment NSID" do
      assert {:ok, "_lexicon.example.com"} = NSID.authority_domain("com.example.record")
    end

    test "handles NSIDs with numbers in segments" do
      assert {:ok, "_lexicon.v0.comet.sh"} = NSID.authority_domain("sh.comet.v0.feed")
    end

    test "returns error for a plain string without dots" do
      assert {:error, :invalid_nsid} = NSID.authority_domain("invalid")
    end

    test "returns error for an empty string" do
      assert {:error, :invalid_nsid} = NSID.authority_domain("")
    end

    test "returns error for a string with invalid characters" do
      assert {:error, :invalid_nsid} = NSID.authority_domain("not.valid!")
    end
  end
end
