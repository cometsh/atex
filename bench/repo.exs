##
## Atex.Repo benchmarks
##
## Run with:
##   mix run bench/repo.exs
##
## Uses the real-world CAR fixtures in test/fixtures/ and the larger repo at
## tmp/ovyerus.car (39 MB, ~90k records) when present.
##
## Each suite section measures a distinct subsystem. Memory measurements are
## enabled with memory_time: 2 (seconds of sampling).
##

alias Atex.Repo

fixture = fn name ->
  File.read!(Path.join("test/fixtures", name))
end

fixture_stream = fn name ->
  File.stream!(Path.join("test/fixtures", name), 65_536, [:raw, :binary])
end

large_path = "tmp/ovyerus.car"
has_large = File.exists?(large_path)

if has_large do
  IO.puts("Large fixture (#{large_path}) found - including in streaming benchmarks.\n")
else
  IO.puts("Large fixture (#{large_path}) not found - skipping large-file benchmarks.\n")
end

# ---------------------------------------------------------------------------
# Pre-load repos used as inputs to export / access benchmarks
# ---------------------------------------------------------------------------

# ~22 KB, 62 records
small_bin = fixture.("alt.car")
# ~46 KB, 123 records
medium_bin = fixture.("comet.car")

{:ok, small_repo} = Repo.from_car(small_bin)
{:ok, medium_repo} = Repo.from_car(medium_bin)

# Pre-fetch one path from each for the get_record benchmark
{:ok, small_pairs} = MST.to_list(small_repo.tree)
{:ok, medium_pairs} = MST.to_list(medium_repo.tree)

small_path = small_pairs |> Enum.at(div(length(small_pairs), 2)) |> elem(0)
medium_path = medium_pairs |> Enum.at(div(length(medium_pairs), 2)) |> elem(0)

small_collection =
  small_pairs |> hd() |> elem(0) |> String.split("/") |> hd()

medium_collection =
  medium_pairs |> hd() |> elem(0) |> String.split("/") |> hd()

# Repos need a signed commit to be exportable via to_car.
jwk = JOSE.JWK.generate_key({:ec, "P-256"})
{:ok, small_repo_committed} = Repo.commit(small_repo, small_repo.commit.did, jwk)
{:ok, medium_repo_committed} = Repo.commit(medium_repo, medium_repo.commit.did, jwk)

IO.puts("=== CAR import ===\n")

Benchee.run(
  %{
    "from_car - small (62 records, ~22 KB)" => fn -> Repo.from_car(small_bin) end,
    "from_car - medium (123 records, ~46 KB)" => fn -> Repo.from_car(medium_bin) end
  },
  time: 5,
  memory_time: 2,
  print: [fast_warning: false]
)

IO.puts("\n=== CAR export (to_car) ===\n")

Benchee.run(
  %{
    "to_car - small (62 records)" => fn -> Repo.to_car(small_repo_committed) end,
    "to_car - medium (123 records)" => fn -> Repo.to_car(medium_repo_committed) end
  },
  time: 5,
  memory_time: 2,
  print: [fast_warning: false]
)

IO.puts("\n=== CAR streaming - small fixtures ===\n")

Benchee.run(
  %{
    "stream_car full - small (62 records)" => fn ->
      fixture_stream.("alt.car")
      |> Repo.stream_car()
      |> Stream.run()
    end,
    "stream_car full - medium (123 records)" => fn ->
      fixture_stream.("comet.car")
      |> Repo.stream_car()
      |> Stream.run()
    end,
    "stream_car take 10 - small" => fn ->
      fixture_stream.("alt.car")
      |> Repo.stream_car()
      |> Stream.filter(&match?({:record, _, _}, &1))
      |> Stream.take(10)
      |> Stream.run()
    end,
    "stream_car take 10 - medium" => fn ->
      fixture_stream.("comet.car")
      |> Repo.stream_car()
      |> Stream.filter(&match?({:record, _, _}, &1))
      |> Stream.take(10)
      |> Stream.run()
    end
  },
  time: 5,
  memory_time: 2,
  print: [fast_warning: false]
)

if has_large do
  IO.puts("\n=== CAR streaming - large fixture (39 MB, ~90k records) ===\n")

  Benchee.run(
    %{
      "stream_car full - large (~90k records)" => fn ->
        File.stream!(large_path, 65_536, [:raw, :binary])
        |> Repo.stream_car()
        |> Stream.run()
      end,
      "stream_car take 100 - large" => fn ->
        File.stream!(large_path, 65_536, [:raw, :binary])
        |> Repo.stream_car()
        |> Stream.filter(&match?({:record, _, _}, &1))
        |> Stream.take(100)
        |> Stream.run()
      end
    },
    time: 10,
    memory_time: 3,
    warmup: 2,
    print: [fast_warning: false]
  )
end

IO.puts("\n=== Record access ===\n")

Benchee.run(
  %{
    "get_record - small repo" => fn -> Repo.get_record(small_repo, small_path) end,
    "get_record - medium repo" => fn -> Repo.get_record(medium_repo, medium_path) end,
    "list_collections - small (#{length(small_pairs)} records)" => fn ->
      Repo.list_collections(small_repo)
    end,
    "list_collections - medium (#{length(medium_pairs)} records)" => fn ->
      Repo.list_collections(medium_repo)
    end,
    "list_record_keys - small, 1 collection" => fn ->
      Repo.list_record_keys(small_repo, small_collection)
    end,
    "list_record_keys - medium, 1 collection" => fn ->
      Repo.list_record_keys(medium_repo, medium_collection)
    end,
    "list_records - small, 1 collection" => fn ->
      Repo.list_records(small_repo, small_collection)
    end,
    "list_records - medium, 1 collection" => fn ->
      Repo.list_records(medium_repo, medium_collection)
    end
  },
  time: 5,
  memory_time: 2,
  print: [fast_warning: false]
)

IO.puts("\n=== Record mutation ===\n")

Benchee.run(
  %{
    "put_record - small repo" => fn ->
      Repo.put_record(small_repo, "app.bsky.feed.post/bench#{System.unique_integer()}", %{
        "text" => "bench"
      })
    end,
    "put_record - medium repo" => fn ->
      Repo.put_record(
        medium_repo,
        "app.bsky.feed.post/bench#{System.unique_integer()}",
        %{"text" => "bench"}
      )
    end,
    "delete_record - small repo" => fn -> Repo.delete_record(small_repo, small_path) end,
    "delete_record - medium repo" => fn -> Repo.delete_record(medium_repo, medium_path) end
  },
  time: 5,
  memory_time: 2,
  print: [fast_warning: false]
)
