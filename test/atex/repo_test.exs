defmodule Atex.RepoTest do
  use ExUnit.Case, async: true

  alias Atex.Repo
  alias Atex.Repo.Path

  @did "did:plc:example"

  defp jwk, do: JOSE.JWK.generate_key({:ec, "P-256"})

  defp committed_repo(key \\ nil) do
    key = key || jwk()
    repo = Repo.new()
    {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"text" => "hello"})
    {:ok, repo} = Repo.commit(repo, @did, key)
    {repo, key}
  end

  # ---------------------------------------------------------------------------
  # new/0
  # ---------------------------------------------------------------------------

  describe "new/0" do
    test "returns an empty repo with no commit" do
      repo = Repo.new()
      assert repo.commit == nil
      assert repo.blocks == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # put_record/3 and get_record/2
  # ---------------------------------------------------------------------------

  describe "put_record/3 and get_record/2" do
    test "round-trips a record" do
      repo = Repo.new()
      record = %{"text" => "hello world", "createdAt" => "2024-01-01T00:00:00Z"}
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", record)
      {:ok, fetched} = Repo.get_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
      assert fetched == record
    end

    test "replaces an existing record" do
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"v" => 1})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"v" => 2})
      {:ok, fetched} = Repo.get_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
      assert fetched["v"] == 2
    end

    test "returns not_found for missing path" do
      repo = Repo.new()
      assert {:error, :not_found} = Repo.get_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
    end

    test "stores multiple records independently" do
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/aaaa", %{"n" => 1})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/bbbb", %{"n" => 2})
      {:ok, r1} = Repo.get_record(repo, "app.bsky.feed.post/aaaa")
      {:ok, r2} = Repo.get_record(repo, "app.bsky.feed.post/bbbb")
      assert r1["n"] == 1
      assert r2["n"] == 2
    end

    test "rejects an invalid path string" do
      repo = Repo.new()
      assert {:error, :invalid_path} = Repo.put_record(repo, "no-slash", %{})
      assert {:error, :invalid_path} = Repo.put_record(repo, "/leading", %{})
      assert {:error, :invalid_path} = Repo.put_record(repo, "a/b/c", %{})
      assert {:error, :invalid_path} = Repo.put_record(repo, "", %{})
    end

    test "accepts an Atex.Repo.Path struct" do
      repo = Repo.new()
      path = Path.new!("app.bsky.feed.post", "3jzfcijpj2z2a")
      {:ok, repo} = Repo.put_record(repo, path, %{"text" => "via struct"})
      {:ok, record} = Repo.get_record(repo, path)
      assert record["text"] == "via struct"
    end

    test "Path struct and equivalent string retrieve the same record" do
      repo = Repo.new()
      path = Path.new!("app.bsky.feed.post", "3jzfcijpj2z2a")
      {:ok, repo} = Repo.put_record(repo, path, %{"text" => "hi"})
      {:ok, r1} = Repo.get_record(repo, path)
      {:ok, r2} = Repo.get_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
      assert r1 == r2
    end
  end

  # ---------------------------------------------------------------------------
  # delete_record/2
  # ---------------------------------------------------------------------------

  describe "delete_record/2" do
    test "removes an existing record" do
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"x" => 1})
      {:ok, repo} = Repo.delete_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
      assert {:error, :not_found} = Repo.get_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
    end

    test "returns not_found for missing path" do
      repo = Repo.new()
      assert {:error, :not_found} = Repo.delete_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
    end

    test "does not affect other records" do
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/aaaa", %{"n" => 1})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/bbbb", %{"n" => 2})
      {:ok, repo} = Repo.delete_record(repo, "app.bsky.feed.post/aaaa")
      assert {:error, :not_found} = Repo.get_record(repo, "app.bsky.feed.post/aaaa")
      assert {:ok, %{"n" => 2}} = Repo.get_record(repo, "app.bsky.feed.post/bbbb")
    end

    test "rejects invalid path" do
      repo = Repo.new()
      assert {:error, :invalid_path} = Repo.delete_record(repo, "bad")
    end

    test "accepts an Atex.Repo.Path struct" do
      repo = Repo.new()
      path = Path.new!("app.bsky.feed.post", "aaaa")
      {:ok, repo} = Repo.put_record(repo, path, %{"n" => 1})
      {:ok, repo} = Repo.delete_record(repo, path)
      assert {:error, :not_found} = Repo.get_record(repo, path)
    end
  end

  # ---------------------------------------------------------------------------
  # commit/3
  # ---------------------------------------------------------------------------

  describe "commit/3" do
    test "sets the commit DID" do
      {repo, _key} = committed_repo()
      assert repo.commit.did == @did
    end

    test "sets version to 3" do
      {repo, _key} = committed_repo()
      assert repo.commit.version == 3
    end

    test "sets prev to nil" do
      {repo, _key} = committed_repo()
      assert repo.commit.prev == nil
    end

    test "rev is a valid TID string" do
      {repo, _key} = committed_repo()
      assert Atex.TID.match?(repo.commit.rev)
    end

    test "produces a non-nil sig" do
      {repo, _key} = committed_repo()
      assert is_binary(repo.commit.sig)
    end

    test "data CID matches the MST root" do
      key = jwk()
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"x" => 1})
      {:ok, repo} = Repo.commit(repo, @did, key)

      assert repo.commit.data == repo.tree.root
    end

    test "rev increases monotonically across sequential commits" do
      key = jwk()
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/aaaa", %{"n" => 1})
      {:ok, repo} = Repo.commit(repo, @did, key)
      rev1 = repo.commit.rev

      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/bbbb", %{"n" => 2})
      {:ok, repo} = Repo.commit(repo, @did, key)
      rev2 = repo.commit.rev

      assert rev2 > rev1
    end
  end

  # ---------------------------------------------------------------------------
  # verify_commit/2
  # ---------------------------------------------------------------------------

  describe "verify_commit/2" do
    test "passes with the correct public key" do
      key = jwk()
      {repo, _} = committed_repo(key)
      assert :ok = Repo.verify_commit(repo, JOSE.JWK.to_public(key))
    end

    test "fails with a different key" do
      {repo, _key} = committed_repo()
      other_key = JOSE.JWK.to_public(jwk())
      assert {:error, _} = Repo.verify_commit(repo, other_key)
    end

    test "returns error when no commit exists" do
      repo = Repo.new()
      assert {:error, :no_commit} = Repo.verify_commit(repo, jwk())
    end
  end

  # ---------------------------------------------------------------------------
  # to_car/1
  # ---------------------------------------------------------------------------

  describe "to_car/1" do
    test "returns error when no commit exists" do
      repo = Repo.new()
      assert {:error, :no_commit} = Repo.to_car(repo)
    end

    test "returns a binary" do
      {repo, _key} = committed_repo()
      assert {:ok, bin} = Repo.to_car(repo)
      assert is_binary(bin)
    end

    test "CAR root is the commit CID" do
      {repo, _key} = committed_repo()
      {:ok, bin} = Repo.to_car(repo)
      {:ok, car} = DASL.CAR.decode(bin)
      {:ok, commit_cid} = Atex.Repo.Commit.cid(repo.commit)
      assert [^commit_cid] = car.roots
    end

    test "empty repo produces a valid CAR" do
      key = jwk()
      repo = Repo.new()
      {:ok, repo} = Repo.commit(repo, @did, key)
      assert {:ok, bin} = Repo.to_car(repo)
      assert is_binary(bin)
    end
  end

  # ---------------------------------------------------------------------------
  # from_car/1
  # ---------------------------------------------------------------------------

  describe "from_car/1" do
    test "round-trips a single-record repo" do
      key = jwk()
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"text" => "hi"})
      {:ok, repo} = Repo.commit(repo, @did, key)
      {:ok, bin} = Repo.to_car(repo)

      {:ok, repo2} = Repo.from_car(bin)
      assert repo2.commit.did == @did
      assert {:ok, %{"text" => "hi"}} = Repo.get_record(repo2, "app.bsky.feed.post/3jzfcijpj2z2a")
    end

    test "round-trips a multi-record repo" do
      key = jwk()
      repo = Repo.new()

      records = [
        {"app.bsky.feed.post/aaaa", %{"n" => 1}},
        {"app.bsky.feed.post/bbbb", %{"n" => 2}},
        {"app.bsky.actor.profile/self", %{"displayName" => "Test"}}
      ]

      repo =
        Enum.reduce(records, repo, fn {path, rec}, acc ->
          {:ok, acc} = Repo.put_record(acc, path, rec)
          acc
        end)

      {:ok, repo} = Repo.commit(repo, @did, key)
      {:ok, bin} = Repo.to_car(repo)
      {:ok, repo2} = Repo.from_car(bin)

      for {path, record} <- records do
        assert {:ok, ^record} = Repo.get_record(repo2, path)
      end
    end

    test "commit signature survives round-trip" do
      key = jwk()
      {repo, _} = committed_repo(key)
      {:ok, bin} = Repo.to_car(repo)
      {:ok, repo2} = Repo.from_car(bin)
      assert :ok = Repo.verify_commit(repo2, JOSE.JWK.to_public(key))
    end

    test "returns error for invalid binary" do
      assert match?({:error, _, _}, Repo.from_car("not a car")) or
               match?({:error, _}, Repo.from_car("not a car"))
    end

    test "round-trips an empty repo" do
      key = jwk()
      repo = Repo.new()
      {:ok, repo} = Repo.commit(repo, @did, key)
      {:ok, bin} = Repo.to_car(repo)
      {:ok, repo2} = Repo.from_car(bin)
      assert repo2.commit.did == @did
    end
  end

  # ---------------------------------------------------------------------------
  # list_collections/1
  # ---------------------------------------------------------------------------

  describe "list_collections/1" do
    test "returns empty list for empty repo" do
      assert {:ok, []} = Repo.list_collections(Repo.new())
    end

    test "returns deduplicated collection names in MST order" do
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/aaaa", %{})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.like/bbbb", %{})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/cccc", %{})
      {:ok, cols} = Repo.list_collections(repo)
      # MST key order: "app.bsky.feed.like/..." < "app.bsky.feed.post/..."
      assert "app.bsky.feed.like" in cols
      assert "app.bsky.feed.post" in cols
      assert length(cols) == 2
    end

    test "each collection appears exactly once" do
      repo = Repo.new()

      repo =
        Enum.reduce(1..5, repo, fn i, acc ->
          {:ok, acc} = Repo.put_record(acc, "app.bsky.feed.post/key#{i}", %{"n" => i})
          acc
        end)

      {:ok, cols} = Repo.list_collections(repo)
      assert cols == ["app.bsky.feed.post"]
    end
  end

  # ---------------------------------------------------------------------------
  # list_record_keys/2
  # ---------------------------------------------------------------------------

  describe "list_record_keys/2" do
    test "returns empty list for empty repo" do
      assert {:ok, []} = Repo.list_record_keys(Repo.new(), "app.bsky.feed.post")
    end

    test "returns empty list for non-existent collection" do
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.like/aaaa", %{})
      assert {:ok, []} = Repo.list_record_keys(repo, "app.bsky.feed.post")
    end

    test "returns rkeys in sorted order" do
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/cccc", %{})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/aaaa", %{})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/bbbb", %{})
      {:ok, keys} = Repo.list_record_keys(repo, "app.bsky.feed.post")
      assert keys == ["aaaa", "bbbb", "cccc"]
    end

    test "does not bleed into adjacent collections" do
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.like/aaaa", %{})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/bbbb", %{})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.graph.follow/cccc", %{})
      {:ok, keys} = Repo.list_record_keys(repo, "app.bsky.feed.post")
      assert keys == ["bbbb"]
    end
  end

  # ---------------------------------------------------------------------------
  # list_records/2
  # ---------------------------------------------------------------------------

  describe "list_records/2" do
    test "returns empty list for empty repo" do
      assert {:ok, []} = Repo.list_records(Repo.new(), "app.bsky.feed.post")
    end

    test "returns {rkey, record} pairs in sorted order" do
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/aaaa", %{"n" => 1})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/bbbb", %{"n" => 2})
      {:ok, records} = Repo.list_records(repo, "app.bsky.feed.post")
      assert Enum.map(records, &elem(&1, 0)) == ["aaaa", "bbbb"]
      assert Enum.map(records, fn {_, r} -> r["n"] end) == [1, 2]
    end

    test "only returns records for the specified collection" do
      repo = Repo.new()
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.like/aaaa", %{"liked" => true})
      {:ok, repo} = Repo.put_record(repo, "app.bsky.feed.post/bbbb", %{"text" => "hi"})
      {:ok, records} = Repo.list_records(repo, "app.bsky.feed.post")
      assert length(records) == 1
      assert {"bbbb", %{"text" => "hi"}} = hd(records)
    end
  end

  # ---------------------------------------------------------------------------
  # stream_car/1
  # ---------------------------------------------------------------------------

  describe "stream_car/1" do
    defp build_committed_repo(records) do
      key = jwk()

      repo =
        Enum.reduce(records, Repo.new(), fn {path, rec}, acc ->
          {:ok, acc} = Repo.put_record(acc, path, rec)
          acc
        end)

      {:ok, repo} = Repo.commit(repo, @did, key)
      {:ok, bin} = Repo.to_car(repo)
      {repo, bin, key}
    end

    test "first item is {:commit, commit}" do
      {_repo, bin, _key} =
        build_committed_repo([{"app.bsky.feed.post/aaaa", %{"n" => 1}}])

      [first | _] = Repo.stream_car([bin]) |> Enum.to_list()
      assert match?({:commit, %Atex.Repo.Commit{}}, first)
    end

    test "commit in stream has correct DID" do
      {_repo, bin, _key} =
        build_committed_repo([{"app.bsky.feed.post/aaaa", %{"n" => 1}}])

      [{:commit, commit} | _] = Repo.stream_car([bin]) |> Enum.to_list()
      assert commit.did == @did
    end

    test "emits a {:record, path, map} for each record" do
      records = [
        {"app.bsky.feed.post/aaaa", %{"n" => 1}},
        {"app.bsky.feed.post/bbbb", %{"n" => 2}}
      ]

      {_repo, bin, _key} = build_committed_repo(records)
      items = Repo.stream_car([bin]) |> Enum.to_list()
      record_items = Enum.filter(items, &match?({:record, _, _}, &1))
      assert length(record_items) == 2

      paths = Enum.map(record_items, fn {:record, path, _} -> to_string(path) end) |> Enum.sort()
      assert paths == ["app.bsky.feed.post/aaaa", "app.bsky.feed.post/bbbb"]
    end

    test "record content is correct" do
      {_repo, bin, _key} =
        build_committed_repo([{"app.bsky.feed.post/aaaa", %{"text" => "hello stream"}}])

      items = Repo.stream_car([bin]) |> Enum.to_list()
      [{:record, path, record}] = Enum.filter(items, &match?({:record, _, _}, &1))
      assert path.collection == "app.bsky.feed.post"
      assert path.rkey == "aaaa"
      assert record["text"] == "hello stream"
    end

    test "path items are Atex.Repo.Path structs" do
      {_repo, bin, _key} =
        build_committed_repo([{"app.bsky.feed.post/aaaa", %{"n" => 1}}])

      items = Repo.stream_car([bin]) |> Enum.to_list()
      [{:record, path, _}] = Enum.filter(items, &match?({:record, _, _}, &1))
      assert %Atex.Repo.Path{} = path
    end

    test "empty repo stream has only commit item" do
      key = jwk()
      repo = Repo.new()
      {:ok, repo} = Repo.commit(repo, @did, key)
      {:ok, bin} = Repo.to_car(repo)
      items = Repo.stream_car([bin]) |> Enum.to_list()
      assert length(items) == 1
      assert match?([{:commit, _}], items)
    end

    test "stream and from_car agree on record content" do
      records = [
        {"app.bsky.feed.post/aaaa", %{"n" => 1}},
        {"app.bsky.actor.profile/self", %{"displayName" => "Test"}}
      ]

      {_repo, bin, _key} = build_committed_repo(records)

      {:ok, repo} = Repo.from_car(bin)

      streamed =
        Repo.stream_car([bin])
        |> Stream.filter(&match?({:record, _, _}, &1))
        |> Enum.map(fn {:record, path, rec} -> {to_string(path), rec} end)
        |> Map.new()

      for {path_str, _record} <- records do
        {:ok, from_car_rec} = Repo.get_record(repo, path_str)
        assert Map.get(streamed, path_str) == from_car_rec
      end
    end
  end
end
