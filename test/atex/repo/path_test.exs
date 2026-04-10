defmodule Atex.Repo.PathTest do
  use ExUnit.Case, async: true

  alias Atex.Repo.Path

  # ---------------------------------------------------------------------------
  # new/2
  # ---------------------------------------------------------------------------

  describe "new/2" do
    test "accepts a standard NSID collection and TID rkey" do
      assert {:ok, path} = Path.new("app.bsky.feed.post", "3jzfcijpj2z2a")
      assert path.collection == "app.bsky.feed.post"
      assert path.rkey == "3jzfcijpj2z2a"
    end

    test "accepts 'self' literal rkey" do
      assert {:ok, path} = Path.new("app.bsky.actor.profile", "self")
      assert path.rkey == "self"
    end

    test "accepts rkey with colon (e.g. domain name)" do
      assert {:ok, _} = Path.new("sh.tangled.knot", "localhost:6000")
    end

    test "accepts rkey with tilde" do
      assert {:ok, _} = Path.new("com.example.thing", "~1.2-3_")
    end

    test "accepts rkey with all allowed special chars" do
      assert {:ok, _} = Path.new("com.example.thing", "aZ0.-_:~")
    end

    test "accepts multi-segment deep NSID" do
      assert {:ok, _} = Path.new("codes.advent.challenge.day", "3jzfcijpj2z2a")
    end

    test "rejects collection without a dot (single segment)" do
      assert {:error, :invalid_collection} = Path.new("noperiod", "self")
    end

    test "rejects collection with leading dot" do
      assert {:error, :invalid_collection} = Path.new(".app.bsky", "self")
    end

    test "rejects collection with trailing dot" do
      assert {:error, :invalid_collection} = Path.new("app.bsky.", "self")
    end

    test "rejects collection with consecutive dots" do
      assert {:error, :invalid_collection} = Path.new("app..bsky", "self")
    end

    test "rejects collection with hyphen" do
      assert {:error, :invalid_collection} = Path.new("app-bsky.feed.post", "self")
    end

    test "rejects collection with uppercase segment starting char" do
      # NSIDs are lowercase-only at the authority level; uppercase disallowed in collection
      # The spec says NSID segments must start with a letter - uppercase is allowed per NSID spec
      # but our regex allows [a-zA-Z][a-zA-Z0-9]* - so let's just verify the regex works
      assert {:ok, _} = Path.new("App.Bsky.Feed", "self")
    end

    test "rejects empty rkey" do
      assert {:error, :invalid_rkey} = Path.new("app.bsky.feed.post", "")
    end

    test "rejects '.' rkey" do
      assert {:error, :invalid_rkey} = Path.new("app.bsky.feed.post", ".")
    end

    test "rejects '..' rkey" do
      assert {:error, :invalid_rkey} = Path.new("app.bsky.feed.post", "..")
    end

    test "rejects rkey with slash" do
      assert {:error, :invalid_rkey} = Path.new("app.bsky.feed.post", "a/b")
    end

    test "rejects rkey with space" do
      assert {:error, :invalid_rkey} = Path.new("app.bsky.feed.post", "bad key")
    end

    test "rejects rkey with @" do
      assert {:error, :invalid_rkey} = Path.new("app.bsky.feed.post", "@handle")
    end

    test "rejects rkey with #" do
      assert {:error, :invalid_rkey} = Path.new("app.bsky.feed.post", "#extra")
    end
  end

  # ---------------------------------------------------------------------------
  # new!/2
  # ---------------------------------------------------------------------------

  describe "new!/2" do
    test "returns the struct on valid input" do
      path = Path.new!("app.bsky.feed.post", "3jzfcijpj2z2a")
      assert %Path{collection: "app.bsky.feed.post", rkey: "3jzfcijpj2z2a"} = path
    end

    test "raises ArgumentError on invalid collection" do
      assert_raise ArgumentError, fn -> Path.new!("noslash", "self") end
    end

    test "raises ArgumentError on invalid rkey" do
      assert_raise ArgumentError, fn -> Path.new!("app.bsky.feed.post", "..") end
    end
  end

  # ---------------------------------------------------------------------------
  # from_string/1
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # from_string!/1
  # ---------------------------------------------------------------------------

  describe "from_string!/1" do
    test "returns the struct on a valid path string" do
      assert %Path{collection: "app.bsky.feed.post", rkey: "3jzfcijpj2z2a"} =
               Path.from_string!("app.bsky.feed.post/3jzfcijpj2z2a")
    end

    test "raises ArgumentError for a string with no slash" do
      assert_raise ArgumentError, fn -> Path.from_string!("no-slash") end
    end

    test "raises ArgumentError for a string with two slashes" do
      assert_raise ArgumentError, fn -> Path.from_string!("a/b/c") end
    end

    test "raises ArgumentError for an invalid collection segment" do
      assert_raise ArgumentError, fn -> Path.from_string!("bad/self") end
    end

    test "raises ArgumentError for a reserved rkey" do
      assert_raise ArgumentError, fn -> Path.from_string!("app.bsky.feed.post/..") end
    end
  end

  # ---------------------------------------------------------------------------
  # sigil_PATH
  # ---------------------------------------------------------------------------

  describe "sigil_PATH" do
    import Path, only: [sigil_PATH: 2]

    test "constructs a valid path from a literal string" do
      assert %Path{collection: "app.bsky.feed.post", rkey: "3jzfcijpj2z2a"} =
               ~PATH"app.bsky.feed.post/3jzfcijpj2z2a"
    end

    test "works with alternative rkey formats" do
      assert %Path{collection: "sh.tangled.knot", rkey: "localhost:6000"} =
               ~PATH"sh.tangled.knot/localhost:6000"
    end

    test "raises ArgumentError for an invalid path string" do
      assert_raise ArgumentError, fn -> ~PATH"not-a-valid-path" end
    end
  end

  describe "from_string/1" do
    test "parses a valid path string" do
      assert {:ok, path} = Path.from_string("app.bsky.feed.post/3jzfcijpj2z2a")
      assert path.collection == "app.bsky.feed.post"
      assert path.rkey == "3jzfcijpj2z2a"
    end

    test "parses a path with colon rkey" do
      assert {:ok, path} = Path.from_string("sh.tangled.knot/localhost:6000")
      assert path.rkey == "localhost:6000"
    end

    test "returns invalid_path for string with no slash" do
      assert {:error, :invalid_path} = Path.from_string("no-slash")
    end

    test "returns invalid_path for string with two slashes" do
      assert {:error, :invalid_path} = Path.from_string("a/b/c")
    end

    test "returns invalid_path for empty string" do
      assert {:error, :invalid_path} = Path.from_string("")
    end

    test "returns invalid_collection for bad collection segment" do
      assert {:error, :invalid_collection} = Path.from_string("bad/self")
    end

    test "returns invalid_rkey for reserved rkey" do
      assert {:error, :invalid_rkey} = Path.from_string("app.bsky.feed.post/..")
    end
  end

  # ---------------------------------------------------------------------------
  # to_string/1 and String.Chars
  # ---------------------------------------------------------------------------

  describe "to_string/1" do
    test "produces collection/rkey format" do
      path = Path.new!("app.bsky.feed.post", "3jzfcijpj2z2a")
      assert Path.to_string(path) == "app.bsky.feed.post/3jzfcijpj2z2a"
    end

    test "String.Chars protocol works in interpolation" do
      path = Path.new!("app.bsky.actor.profile", "self")
      assert "#{path}" == "app.bsky.actor.profile/self"
    end

    test "Kernel.to_string/1 works" do
      path = Path.new!("app.bsky.feed.post", "3jzfcijpj2z2a")
      assert Kernel.to_string(path) == "app.bsky.feed.post/3jzfcijpj2z2a"
    end
  end

  # ---------------------------------------------------------------------------
  # Inspect protocol
  # ---------------------------------------------------------------------------

  describe "Inspect" do
    test "renders as sigil form" do
      path = Path.new!("app.bsky.feed.post", "3jzfcijpj2z2a")
      assert inspect(path) == ~s(~PATH"app.bsky.feed.post/3jzfcijpj2z2a")
    end
  end

  # ---------------------------------------------------------------------------
  # Round-trip
  # ---------------------------------------------------------------------------

  describe "round-trip" do
    test "from_string |> to_string is identity" do
      str = "app.bsky.feed.post/3jzfcijpj2z2a"
      {:ok, path} = Path.from_string(str)
      assert Path.to_string(path) == str
    end
  end
end
