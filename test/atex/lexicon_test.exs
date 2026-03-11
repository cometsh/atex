defmodule Atex.LexiconTest do
  use ExUnit.Case, async: true

  # Fixture modules are defined in test/support/lexicon_fixtures.ex and
  # compiled before tests run via the :test elixirc_paths config in mix.exs.

  # ---------------------------------------------------------------------------
  # Tests: ref-typed procedure input (local ref)
  # ---------------------------------------------------------------------------

  describe "procedure with local ref-typed input" do
    test "generates an Input submodule" do
      assert Code.ensure_loaded?(Lexicon.Test.CreatePost.Input)
    end

    test "Input submodule exports from_json/1" do
      assert function_exported?(Lexicon.Test.CreatePost.Input, :from_json, 1)
    end

    test "from_json/1 succeeds for valid data" do
      assert {:ok, result} = Lexicon.Test.CreatePost.Input.from_json(%{"text" => "hello"})
      assert result.text == "hello"
    end

    test "from_json/1 returns error for invalid data" do
      assert {:error, _} = Lexicon.Test.CreatePost.Input.from_json(%{})
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: ref-typed query output (local ref)
  # ---------------------------------------------------------------------------

  describe "query with local ref-typed output" do
    test "generates an Output submodule" do
      assert Code.ensure_loaded?(Lexicon.Test.GetPost.Output)
    end

    test "Output submodule exports from_json/1" do
      assert function_exported?(Lexicon.Test.GetPost.Output, :from_json, 1)
    end

    test "from_json/1 succeeds for valid data" do
      assert {:ok, result} =
               Lexicon.Test.GetPost.Output.from_json(%{
                 "uri" => "at://did:plc:abc/app.bsky.feed.post/123"
               })

      assert result.uri == "at://did:plc:abc/app.bsky.feed.post/123"
    end

    test "from_json/1 returns error for invalid data" do
      assert {:error, _} = Lexicon.Test.GetPost.Output.from_json(%{})
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: ref-typed procedure input (cross-NSID ref targeting a `main` def)
  # ---------------------------------------------------------------------------

  describe "procedure with cross-NSID ref-typed input" do
    test "generates an Input submodule" do
      assert Code.ensure_loaded?(Lexicon.Test.CreateProfile.Input)
    end

    test "Input submodule exports from_json/1" do
      assert function_exported?(Lexicon.Test.CreateProfile.Input, :from_json, 1)
    end

    test "from_json/1 delegates to the referenced module" do
      assert {:ok, result} =
               Lexicon.Test.CreateProfile.Input.from_json(%{"did" => "did:plc:abc"})

      assert result.did == "did:plc:abc"
    end

    test "from_json/1 returns error when referenced module rejects data" do
      assert {:error, _} = Lexicon.Test.CreateProfile.Input.from_json(%{})
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: union-typed procedure input (local refs)
  # ---------------------------------------------------------------------------

  describe "procedure with union-typed input" do
    test "generates an Input submodule" do
      assert Code.ensure_loaded?(Lexicon.Test.CreateUnion.Input)
    end

    test "Input submodule exports from_json/1" do
      assert function_exported?(Lexicon.Test.CreateUnion.Input, :from_json, 1)
    end

    test "from_json/1 succeeds for the first union member" do
      assert {:ok, result} = Lexicon.Test.CreateUnion.Input.from_json(%{"text" => "hello"})
      assert result.text == "hello"
    end

    test "from_json/1 succeeds for the second union member" do
      assert {:ok, result} = Lexicon.Test.CreateUnion.Input.from_json(%{"error" => "bad"})
      assert result.error == "bad"
    end

    test "from_json/1 returns :no_matching_type when no member matches" do
      assert {:error, :no_matching_type} =
               Lexicon.Test.CreateUnion.Input.from_json(%{"unknown" => "field"})
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: raw-input procedure (encoding only, no schema)
  # ---------------------------------------------------------------------------

  describe "procedure with raw input (encoding only)" do
    test "does not generate an Input submodule" do
      refute Code.ensure_loaded?(Lexicon.Test.UploadBlob.Input)
    end

    test "root module exports content_type/0" do
      assert function_exported?(Lexicon.Test.UploadBlob, :content_type, 0)
    end

    test "content_type/0 returns the declared encoding" do
      assert Lexicon.Test.UploadBlob.content_type() == "image/jpeg"
    end

    test "root module has raw_input field in struct" do
      assert Map.has_key?(%Lexicon.Test.UploadBlob{}, :raw_input)
    end
  end

  describe "procedure with wildcard raw input encoding" do
    test "content_type/0 returns */*" do
      assert Lexicon.Test.UploadAny.content_type() == "*/*"
    end
  end

  describe "procedure with JSON input schema" do
    test "Input submodule exports content_type/0" do
      assert function_exported?(Lexicon.Test.CreatePost.Input, :content_type, 0)
    end

    test "Input.content_type/0 returns the declared encoding" do
      assert Lexicon.Test.CreatePost.Input.content_type() == "application/json"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: union-typed query output (cross-NSID refs)
  # ---------------------------------------------------------------------------

  describe "query with union-typed output (cross-NSID)" do
    test "generates an Output submodule" do
      assert Code.ensure_loaded?(Lexicon.Test.GetUnion.Output)
    end

    test "Output submodule exports from_json/1" do
      assert function_exported?(Lexicon.Test.GetUnion.Output, :from_json, 1)
    end

    test "from_json/1 succeeds for the first union member" do
      assert {:ok, result} = Lexicon.Test.GetUnion.Output.from_json(%{"did" => "did:plc:abc"})
      assert result.did == "did:plc:abc"
    end

    test "from_json/1 succeeds for the second union member" do
      assert {:ok, result} = Lexicon.Test.GetUnion.Output.from_json(%{"error" => "oops"})
      assert result.error == "oops"
    end

    test "from_json/1 returns :no_matching_type when no member matches" do
      assert {:error, :no_matching_type} = Lexicon.Test.GetUnion.Output.from_json(%{})
    end
  end
end
