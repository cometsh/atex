defmodule Atex.Repo.FixturesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Parses real-world AT Protocol repository CAR exports from test/fixtures/.

  These verify that `Atex.Repo.from_car/1` correctly handles actual PDS-
  exported repositories, including commit decoding, MST reconstruction, and
  individual record retrieval.
  """

  alias Atex.Repo
  alias Atex.Repo.Path, as: RepoPath

  defp fixture_path(name), do: Elixir.Path.join([__DIR__, "../../fixtures", name])
  defp fixture(name), do: File.read!(fixture_path(name))
  defp fixture_stream(name), do: File.stream!(fixture_path(name), 65_536, [:raw, :binary])

  # ---------------------------------------------------------------------------
  # comet.car - did:web:comet.sh
  # ---------------------------------------------------------------------------

  describe "comet.car (did:web:comet.sh)" do
    setup do
      {:ok, repo} = fixture("comet.car") |> Repo.from_car()
      {:ok, pairs} = MST.to_list(repo.tree)
      %{repo: repo, pairs: pairs}
    end

    test "decodes the commit", %{repo: repo} do
      assert repo.commit.did == "did:web:comet.sh"
      assert repo.commit.version == 3
      assert repo.commit.rev == "3mi3cqkyzsv22"
      assert is_binary(repo.commit.sig)
    end

    test "commit CID matches CAR root" do
      bin = fixture("comet.car")
      {:ok, car} = DASL.CAR.decode(bin)
      {:ok, repo} = Repo.from_car(bin)
      {:ok, commit_cid} = Atex.Repo.Commit.cid(repo.commit)
      assert [^commit_cid] = car.roots
    end

    test "reconstructs the correct number of records", %{pairs: pairs} do
      assert length(pairs) == 123
    end

    test "contains the expected collections", %{pairs: pairs} do
      collections =
        pairs
        |> Enum.map(fn {k, _} -> k |> String.split("/") |> hd() end)
        |> Enum.uniq()
        |> Enum.sort()

      assert "app.bsky.actor.profile" in collections
      assert "app.bsky.feed.post" in collections
      assert "app.bsky.feed.like" in collections
      assert "app.bsky.graph.follow" in collections
      assert "sh.tangled.actor.profile" in collections
      assert "sh.tangled.repo" in collections
    end

    test "retrieves the Bluesky profile record", %{repo: repo} do
      {:ok, profile} = Repo.get_record(repo, "app.bsky.actor.profile/self")
      assert profile["displayName"] == "comet.sh"
      assert profile["$type"] == "app.bsky.actor.profile"
    end

    test "retrieves a Tangled profile record", %{repo: repo} do
      {:ok, profile} = Repo.get_record(repo, "sh.tangled.actor.profile/self")
      assert is_map(profile)
    end

    test "returns not_found for a non-existent path", %{repo: repo} do
      assert {:error, :not_found} =
               Repo.get_record(repo, "app.bsky.feed.post/doesnotexist")
    end

    test "all MST leaf CIDs match their record blocks", %{repo: repo, pairs: pairs} do
      for {path, cid} <- pairs do
        assert {:ok, _record} = Repo.get_record(repo, path),
               "expected to decode record at #{path}"

        assert Map.has_key?(repo.blocks, cid),
               "expected block for #{path} (#{DASL.CID.encode(cid)}) to be present"
      end
    end

    test "MST root CID matches commit data field", %{repo: repo} do
      assert repo.tree.root == repo.commit.data
    end

    test "list_collections returns expected collections", %{repo: repo} do
      {:ok, cols} = Repo.list_collections(repo)
      assert "app.bsky.feed.post" in cols
      assert "app.bsky.feed.like" in cols
      assert "sh.tangled.actor.profile" in cols
      assert "sh.tangled.repo" in cols
      # Collections are in MST byte order, not necessarily lexicographic order.
      assert length(cols) == length(Enum.uniq(cols))
    end

    test "list_record_keys returns rkeys for a collection", %{repo: repo} do
      {:ok, keys} = Repo.list_record_keys(repo, "app.bsky.feed.post")
      assert keys != []
      assert Enum.all?(keys, &is_binary/1)
      assert keys == Enum.sort(keys)
    end

    test "list_records round-trips record content", %{repo: repo} do
      {:ok, records} = Repo.list_records(repo, "app.bsky.actor.profile")
      assert length(records) == 1
      {"self", profile} = hd(records)
      assert profile["displayName"] == "comet.sh"
    end

    test "stream_car emits commit then all records (via File.stream!)" do
      items = fixture_stream("comet.car") |> Repo.stream_car() |> Enum.to_list()
      [{:commit, commit} | rest] = items
      assert commit.did == "did:web:comet.sh"
      record_items = Enum.filter(rest, &match?({:record, _, _}, &1))
      assert length(record_items) == 123
    end

    test "stream_car record paths are Atex.Repo.Path structs" do
      fixture_stream("comet.car")
      |> Repo.stream_car()
      |> Stream.filter(&match?({:record, _, _}, &1))
      |> Enum.each(fn {:record, path, _} ->
        assert %RepoPath{} = path
      end)
    end

    test "stream_car and from_car agree on all record content", %{repo: repo} do
      streamed =
        fixture_stream("comet.car")
        |> Repo.stream_car()
        |> Stream.filter(&match?({:record, _, _}, &1))
        |> Enum.map(fn {:record, path, rec} -> {to_string(path), rec} end)
        |> Map.new()

      {:ok, pairs} = MST.to_list(repo.tree)

      for {path_str, _cid} <- pairs do
        {:ok, from_car_rec} = Repo.get_record(repo, path_str)

        assert Map.get(streamed, path_str) == from_car_rec,
               "mismatch at #{path_str}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # alt.car - did:plc:xl2n6atcb6vz3ajmf6bnbrmw
  # ---------------------------------------------------------------------------

  describe "alt.car (did:plc:xl2n6atcb6vz3ajmf6bnbrmw)" do
    setup do
      {:ok, repo} = fixture("alt.car") |> Repo.from_car()
      {:ok, pairs} = MST.to_list(repo.tree)
      %{repo: repo, pairs: pairs}
    end

    test "decodes the commit", %{repo: repo} do
      assert repo.commit.did == "did:plc:xl2n6atcb6vz3ajmf6bnbrmw"
      assert repo.commit.version == 3
      assert repo.commit.rev == "3mgbwezwku722"
      assert is_binary(repo.commit.sig)
    end

    test "commit CID matches CAR root" do
      bin = fixture("alt.car")
      {:ok, car} = DASL.CAR.decode(bin)
      {:ok, repo} = Repo.from_car(bin)
      {:ok, commit_cid} = Atex.Repo.Commit.cid(repo.commit)
      assert [^commit_cid] = car.roots
    end

    test "reconstructs the correct number of records", %{pairs: pairs} do
      assert length(pairs) == 62
    end

    test "contains the expected collections", %{pairs: pairs} do
      collections =
        pairs
        |> Enum.map(fn {k, _} -> k |> String.split("/") |> hd() end)
        |> Enum.uniq()
        |> Enum.sort()

      assert "app.bsky.actor.profile" in collections
      assert "app.bsky.feed.post" in collections
      assert "app.bsky.feed.like" in collections
      assert "sh.tangled.knot" in collections
      assert "xyz.statusphere.status" in collections
    end

    test "retrieves the Bluesky profile record", %{repo: repo} do
      {:ok, profile} = Repo.get_record(repo, "app.bsky.actor.profile/self")
      assert profile["displayName"] == "ovyerus alt"
      assert profile["$type"] == "app.bsky.actor.profile"
    end

    test "returns not_found for a non-existent path", %{repo: repo} do
      assert {:error, :not_found} =
               Repo.get_record(repo, "app.bsky.feed.post/doesnotexist")
    end

    test "all MST leaf CIDs match their record blocks", %{repo: repo, pairs: pairs} do
      for {path, cid} <- pairs do
        assert {:ok, _record} = Repo.get_record(repo, path),
               "expected to decode record at #{path}"

        assert Map.has_key?(repo.blocks, cid),
               "expected block for #{path} (#{DASL.CID.encode(cid)}) to be present"
      end
    end

    test "MST root CID matches commit data field", %{repo: repo} do
      assert repo.tree.root == repo.commit.data
    end

    test "list_collections returns expected collections", %{repo: repo} do
      {:ok, cols} = Repo.list_collections(repo)
      assert "app.bsky.feed.post" in cols
      assert "sh.tangled.knot" in cols
      assert "xyz.statusphere.status" in cols
      # Collections are in MST byte order, not necessarily lexicographic order.
      assert length(cols) == length(Enum.uniq(cols))
    end

    test "list_record_keys returns rkeys including colon rkeys", %{repo: repo} do
      {:ok, keys} = Repo.list_record_keys(repo, "sh.tangled.knot")
      assert "localhost:6000" in keys
    end

    test "list_records round-trips record content", %{repo: repo} do
      {:ok, records} = Repo.list_records(repo, "app.bsky.actor.profile")
      assert length(records) == 1
      {"self", profile} = hd(records)
      assert profile["displayName"] == "ovyerus alt"
    end

    test "stream_car emits commit then all records (via File.stream!)" do
      items = fixture_stream("alt.car") |> Repo.stream_car() |> Enum.to_list()
      [{:commit, commit} | rest] = items
      assert commit.did == "did:plc:xl2n6atcb6vz3ajmf6bnbrmw"
      record_items = Enum.filter(rest, &match?({:record, _, _}, &1))
      assert length(record_items) == 62
    end

    test "stream_car handles colon rkey paths" do
      paths =
        fixture_stream("alt.car")
        |> Repo.stream_car()
        |> Stream.filter(&match?({:record, _, _}, &1))
        |> Enum.map(fn {:record, path, _} -> to_string(path) end)

      assert "sh.tangled.knot/localhost:6000" in paths
    end

    test "stream_car and from_car agree on all record content", %{repo: repo} do
      streamed =
        fixture_stream("alt.car")
        |> Repo.stream_car()
        |> Stream.filter(&match?({:record, _, _}, &1))
        |> Enum.map(fn {:record, path, rec} -> {to_string(path), rec} end)
        |> Map.new()

      {:ok, pairs} = MST.to_list(repo.tree)

      for {path_str, _cid} <- pairs do
        {:ok, from_car_rec} = Repo.get_record(repo, path_str)

        assert Map.get(streamed, path_str) == from_car_rec,
               "mismatch at #{path_str}"
      end
    end
  end
end
