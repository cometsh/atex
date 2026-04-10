defmodule Atex.Repo do
  @moduledoc """
  AT Protocol repository - a signed, content-addressed store of records.

  A repository is a key/value mapping of repo paths (`collection/rkey`) to
  records (CBOR objects), backed by a Merkle Search Tree (MST). Each published
  version of the tree is captured in a signed `Atex.Repo.Commit`.

  ## Quick start

      # Create a new empty repository
      repo = Atex.Repo.new()

      # Insert records (string path or Atex.Repo.Path struct)
      {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"text" => "hello"})

      # Commit (sign) the current tree state
      jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      {:ok, repo} = Atex.Repo.commit(repo, "did:plc:example", jwk)

      # Export to a CAR file
      {:ok, car_binary} = Atex.Repo.to_car(repo)

      # Round-trip import
      {:ok, repo2} = Atex.Repo.from_car(car_binary)

      # Verify the commit signature
      :ok = Atex.Repo.verify_commit(repo2, JOSE.JWK.to_public(jwk))

  ## Paths

  Record paths can be passed as plain strings (`"collection/rkey"`) or as
  `Atex.Repo.Path` structs. Both are accepted by all path-taking functions.
  See `Atex.Repo.Path` for validation rules and struct API.

  ## Record storage

  Records are DRISL CBOR-encoded. Their CIDs (`:drisl` codec) are stored as
  leaf values in the MST. The raw record bytes are tracked in a separate
  `blocks` map inside the struct so they are available for CAR export without
  re-encoding.

  ## CAR serialization

  `to_car/1` produces a CARv1 file in the streamable block order described in
  the spec: commit first, then MST nodes in depth-first pre-order, interleaved
  with their record blocks.

  `from_car/1` decodes a CAR file, extracts the signed commit from the first
  root CID, loads the MST, and collects all record blocks. It does **not**
  verify the commit signature - call `verify_commit/2` explicitly.

  `stream_car/1` provides a lazy stream over a CAR binary, emitting
  `{:commit, commit}` then `{:record, path, record}` tuples without loading
  the full repository into memory. Requires a streamable-order CAR (commit
  first, MST nodes in pre-order before their records).

  ATProto spec: https://atproto.com/specs/repository
  """

  use TypedStruct
  alias Atex.{Repo.Commit, Repo.Path, TID}
  alias DASL.{CAR, CID, DRISL}
  alias MST.{Node, Store, Tree}

  typedstruct enforce: true do
    @typedoc "An AT Protocol repository."

    field :tree, Tree.t()
    field :commit, Commit.t() | nil
    field :blocks, %{CID.t() => binary()}, default: %{}
  end

  @doc """
  Returns a new empty repository with no records and no commit.

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> repo.commit
      nil

  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      tree: MST.new(),
      commit: nil,
      blocks: %{}
    }
  end

  @doc """
  Retrieves the record at `path`, returning the decoded map.

  `path` may be a `"collection/rkey"` string or an `Atex.Repo.Path` struct.

  Returns `{:error, :not_found}` if the path does not exist.

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"text" => "hi"})
      iex> {:ok, record} = Atex.Repo.get_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
      iex> record["text"]
      "hi"

  """
  @spec get_record(t(), String.t() | Path.t()) ::
          {:ok, map()}
          | {:error, :not_found | :invalid_path | :invalid_collection | :invalid_rkey | atom()}
  def get_record(%__MODULE__{} = repo, path) do
    with {:ok, path_str} <- coerce_path(path),
         {:ok, cid} <- MST.get(repo.tree, path_str),
         {:ok, bytes} <- fetch_block(repo.blocks, cid),
         {:ok, record, _rest} <- DRISL.decode(bytes) do
      {:ok, record}
    end
  end

  @doc """
  Inserts or replaces the record at `path`.

  `path` may be a `"collection/rkey"` string or an `Atex.Repo.Path` struct.

  The record is DRISL CBOR-encoded and its CID computed. The CID is inserted
  into the MST as a leaf value. The commit is **not** updated - call
  `commit/3` to sign the new tree state.

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"text" => "hi"})
      iex> {:ok, record} = Atex.Repo.get_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
      iex> record["text"]
      "hi"

  """
  @spec put_record(t(), String.t() | Path.t(), map()) ::
          {:ok, t()} | {:error, :invalid_path | :invalid_collection | :invalid_rkey | atom()}
  def put_record(%__MODULE__{} = repo, path, record) when is_map(record) do
    with {:ok, path_str} <- coerce_path(path),
         {:ok, bytes} <- DRISL.encode(record),
         cid = CID.compute(bytes, :drisl),
         {:ok, tree} <- MST.put(repo.tree, path_str, cid) do
      {:ok, %{repo | tree: tree, blocks: Map.put(repo.blocks, cid, bytes)}}
    end
  end

  @doc """
  Removes the record at `path`.

  `path` may be a `"collection/rkey"` string or an `Atex.Repo.Path` struct.

  Returns `{:error, :not_found}` if the path does not exist.

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"text" => "hi"})
      iex> {:ok, repo} = Atex.Repo.delete_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
      iex> Atex.Repo.get_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a")
      {:error, :not_found}

  """
  @spec delete_record(t(), String.t() | Path.t()) ::
          {:ok, t()}
          | {:error, :not_found | :invalid_path | :invalid_collection | :invalid_rkey | atom()}
  def delete_record(%__MODULE__{} = repo, path) do
    with {:ok, path_str} <- coerce_path(path),
         {:ok, tree} <- MST.delete(repo.tree, path_str) do
      {:ok, %{repo | tree: tree}}
    end
  end

  @doc """
  Signs the current tree state and stores the result as the repository commit.

  Builds an `Atex.Repo.Commit` for `did` referencing the current MST root,
  signs it with `signing_key`, and updates `repo.commit`. The `rev` is set to
  the current timestamp as a TID string, guaranteed to be monotonically
  increasing relative to any previous commit in this process.

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, repo} = Atex.Repo.commit(repo, "did:plc:example", jwk)
      iex> repo.commit.did
      "did:plc:example"
      iex> repo.commit.version
      3

  """
  @spec commit(t(), String.t(), JOSE.JWK.t()) :: {:ok, t()} | {:error, atom()}
  def commit(%__MODULE__{} = repo, did, signing_key) do
    data_cid = mst_root_cid(repo.tree)
    rev = TID.now() |> TID.encode()

    unsigned =
      Commit.new(
        did: did,
        data: data_cid,
        rev: rev,
        prev: nil
      )

    with {:ok, signed} <- Commit.sign(unsigned, signing_key) do
      {:ok, %{repo | commit: signed}}
    end
  end

  @doc """
  Returns a deduplicated list of all collection names in the repository.

  Collections are returned in MST key order (bytewise-lexicographic on the
  full `collection/rkey` path string). This is generally close to but not
  identical to alphabetical order - for example, `"foo.bar"` sorts after
  `"foo.bar.baz"` because `/` (0x2F) > `.` (0x2E).

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/aaaa", %{})
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.like/bbbb", %{})
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/bbbb", %{})
      iex> {:ok, cols} = Atex.Repo.list_collections(repo)
      iex> cols
      ["app.bsky.feed.like", "app.bsky.feed.post"]

  """
  @spec list_collections(t()) :: {:ok, [String.t()]} | {:error, atom()}
  def list_collections(%__MODULE__{tree: tree}) do
    result =
      tree
      |> MST.stream()
      |> Stream.map(fn {key, _cid} -> collection_from_key(key) end)
      |> Stream.dedup()
      |> Enum.to_list()

    {:ok, result}
  rescue
    e -> {:error, {:stream_error, e}}
  end

  @doc """
  Returns a sorted list of all record keys within `collection`.

  The list is in MST key order, which for TID-keyed records is chronological.
  Returns an empty list (not an error) when the collection exists in the repo
  but has no records, or does not exist at all.

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/aaaa", %{})
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/bbbb", %{})
      iex> {:ok, keys} = Atex.Repo.list_record_keys(repo, "app.bsky.feed.post")
      iex> keys
      ["aaaa", "bbbb"]

  """
  @spec list_record_keys(t(), String.t()) :: {:ok, [String.t()]} | {:error, atom()}
  def list_record_keys(%__MODULE__{tree: tree}, collection) when is_binary(collection) do
    prefix = collection <> "/"

    result =
      tree
      |> MST.stream()
      |> stream_collection(prefix)
      |> Stream.map(fn {key, _cid} -> String.slice(key, byte_size(prefix)..-1//1) end)
      |> Enum.to_list()

    {:ok, result}
  rescue
    e -> {:error, {:stream_error, e}}
  end

  @doc """
  Returns a sorted list of `{rkey, record_map}` pairs for all records in
  `collection`.

  The list is in MST key order. Returns an empty list when the collection does
  not exist or has no records.

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/aaaa", %{"n" => 1})
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/bbbb", %{"n" => 2})
      iex> {:ok, records} = Atex.Repo.list_records(repo, "app.bsky.feed.post")
      iex> Enum.map(records, fn {rkey, _} -> rkey end)
      ["aaaa", "bbbb"]

  """
  @spec list_records(t(), String.t()) ::
          {:ok, [{String.t(), map()}]} | {:error, atom()}
  def list_records(%__MODULE__{tree: tree, blocks: blocks}, collection)
      when is_binary(collection) do
    prefix = collection <> "/"

    result =
      tree
      |> MST.stream()
      |> stream_collection(prefix)
      |> Enum.reduce_while([], fn {key, cid}, acc ->
        rkey = String.slice(key, byte_size(prefix)..-1//1)

        case decode_record(blocks, cid) do
          {:ok, record} -> {:cont, [{rkey, record} | acc]}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:error, _} = err -> err
      pairs -> {:ok, Enum.reverse(pairs)}
    end
  rescue
    e -> {:error, {:stream_error, e}}
  end

  @doc """
  Exports the repository as a CARv1 binary.

  Block ordering follows the streamable convention from the spec:

  1. The signed commit block.
  2. The MST root node, then MST nodes in depth-first pre-order, with each
     record block immediately following the MST entry that references it.

  Returns `{:error, :no_commit}` if `commit/3` has not been called.

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"text" => "hello"})
      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, repo} = Atex.Repo.commit(repo, "did:plc:example", jwk)
      iex> {:ok, bin} = Atex.Repo.to_car(repo)
      iex> is_binary(bin)
      true

  """
  @spec to_car(t()) :: {:ok, binary()} | {:error, :no_commit | atom()}
  def to_car(%__MODULE__{commit: nil}), do: {:error, :no_commit}

  def to_car(%__MODULE__{commit: commit, tree: tree, blocks: record_blocks}) do
    with {:ok, commit_cid} <- Commit.cid(commit),
         {:ok, commit_bytes} <- Commit.encode(commit),
         {:ok, ordered_blocks} <- collect_ordered_blocks(tree, record_blocks) do
      # Encode with explicit ordering: commit block must be first so that
      # stream_car/1 can emit {:commit, _} before any {:record, _, _} items.
      encode_car_ordered(commit_cid, commit_bytes, ordered_blocks)
    end
  end

  @doc """
  Decodes a CARv1 binary into a repository struct.

  The first root CID in the CAR header must point to a valid signed commit
  block. The MST is reconstructed from the remaining `:drisl` codec blocks.
  Record blocks are collected into `repo.blocks`.

  The commit signature is **not** verified. Call `verify_commit/2` explicitly
  if you need to authenticate the repository.

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/3jzfcijpj2z2a", %{"text" => "hello"})
      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, repo} = Atex.Repo.commit(repo, "did:plc:example", jwk)
      iex> {:ok, bin} = Atex.Repo.to_car(repo)
      iex> {:ok, repo2} = Atex.Repo.from_car(bin)
      iex> repo2.commit.did
      "did:plc:example"

  """
  @spec from_car(binary()) :: {:ok, t()} | {:error, atom()}
  def from_car(binary) when is_binary(binary) do
    with {:ok, car} <- CAR.decode(binary),
         {:ok, commit_cid} <- car_root_cid(car),
         {:ok, commit} <- decode_commit_block(car.blocks, commit_cid),
         {:ok, tree, record_blocks} <- build_tree_from_car(car.blocks, commit_cid, commit.data) do
      {:ok, %__MODULE__{tree: tree, commit: commit, blocks: record_blocks}}
    end
  end

  @doc """
  Returns a lazy stream over a CARv1 chunk stream, emitting decoded items
  without loading the full repository into memory.

  `chunk_stream` must be an `Enumerable` that yields binary chunks of any
  size - for example `File.stream!("repo.car", [], 65_536)` or a chunked
  HTTP response body. Passing a plain binary also works but is equivalent to
  loading it into memory first; prefer `from_car/1` in that case.

  The stream emits:

  - `{:commit, Atex.Repo.Commit.t()}` - the first item, decoded from the CAR
    root block
  - `{:record, Atex.Repo.Path.t(), map()}` - one per record, decoded in the
    order they appear in the CAR

  The CAR must be in streamable pre-order: commit block first, then MST nodes
  before their child nodes and records. This is the format produced by
  `to_car/1` and by spec-compliant PDS exports. For CARs with arbitrary block
  ordering use `from_car/1` instead.

  If a record block is encountered before its parent MST node has been seen
  (i.e. the path cannot be resolved from already-decoded nodes), the stream
  emits `{:error, :unresolvable_record, cid}` and halts. Parse errors raise a
  `RuntimeError` (consistent with `DASL.CAR.stream_decode/2` semantics).

  ## Examples

  From a file without loading it fully into memory:

      File.stream!("repo.car", 65_536, [:raw, :binary])
      |> Atex.Repo.stream_car()
      |> Enum.each(fn
        {:commit, commit} -> IO.puts(commit.did)
        {:record, path, record} -> IO.inspect({to_string(path), record})
      end)

  From a binary (e.g. in tests):

      iex> repo = Atex.Repo.new()
      iex> {:ok, repo} = Atex.Repo.put_record(repo, "app.bsky.feed.post/aaaa", %{"n" => 1})
      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, repo} = Atex.Repo.commit(repo, "did:plc:example", jwk)
      iex> {:ok, bin} = Atex.Repo.to_car(repo)
      iex> items = Atex.Repo.stream_car([bin]) |> Enum.to_list()
      iex> match?([{:commit, _} | _], items)
      true
      iex> Enum.any?(items, &match?({:record, _, _}, &1))
      true

  Partial consumption with `Stream.take/2` works without raising:

      File.stream!("repo.car", 65_536, [:raw, :binary])
      |> Atex.Repo.stream_car()
      |> Stream.filter(&match?({:record, _, _}, &1))
      |> Stream.take(10)
      |> Enum.to_list()

  """
  @spec stream_car(Enumerable.t()) :: Enumerable.t()
  def stream_car(chunk_stream) do
    # safe_car_decode/1 wraps CAR.stream_decode so that halting the stream
    # early (Stream.take, Enum.reduce_while with :halt, etc.) does not raise.
    # Items are emitted as each incoming chunk is processed - no buffering.
    chunk_stream
    |> safe_car_decode()
    |> Stream.transform(
      fn -> %{commit_cid: nil, cid_to_path: %{}, halted: false} end,
      &reduce_car_item/2,
      fn _ -> :ok end
    )
  end

  @doc """
  Verifies the commit signature against the given public key.

  Delegates to `Atex.Repo.Commit.verify/2`.

  ## Examples

      iex> repo = Atex.Repo.new()
      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, repo} = Atex.Repo.commit(repo, "did:plc:example", jwk)
      iex> Atex.Repo.verify_commit(repo, JOSE.JWK.to_public(jwk))
      :ok

  """
  @spec verify_commit(t(), JOSE.JWK.t()) :: :ok | {:error, :no_commit | atom()}
  def verify_commit(%__MODULE__{commit: nil}, _jwk), do: {:error, :no_commit}

  def verify_commit(%__MODULE__{commit: commit}, jwk) do
    Commit.verify(commit, jwk)
  end

  # ---------------------------------------------------------------------------
  # Private - path coercion
  # ---------------------------------------------------------------------------

  @spec coerce_path(String.t() | Path.t()) ::
          {:ok, String.t()} | {:error, :invalid_path | :invalid_collection | :invalid_rkey}
  defp coerce_path(%Path{} = path), do: {:ok, Path.to_string(path)}

  defp coerce_path(string) when is_binary(string) do
    case Path.from_string(string) do
      {:ok, _} -> {:ok, string}
      {:error, _} = err -> err
    end
  end

  # ---------------------------------------------------------------------------
  # Private - collection streaming helpers
  # ---------------------------------------------------------------------------

  @spec collection_from_key(String.t()) :: String.t()
  defp collection_from_key(key) do
    key |> String.split("/", parts: 2) |> hd()
  end

  # Filters an MST key stream to only those belonging to `prefix`, halting
  # once the first key past the prefix is encountered (exploiting sort order).
  @spec stream_collection(Enumerable.t(), String.t()) :: Enumerable.t()
  defp stream_collection(stream, prefix) do
    stream
    |> Stream.transform(:before, fn {key, cid}, state ->
      cond do
        String.starts_with?(key, prefix) -> {[{key, cid}], :in}
        state == :in -> {:halt, :done}
        true -> {[], :before}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private - record block decoding
  # ---------------------------------------------------------------------------

  @spec decode_record(%{CID.t() => binary()}, CID.t()) :: {:ok, map()} | {:error, atom()}
  defp decode_record(blocks, cid) do
    with {:ok, bytes} <- fetch_block(blocks, cid),
         {:ok, record, _rest} <- DRISL.decode(bytes) do
      {:ok, record}
    end
  end

  # ---------------------------------------------------------------------------
  # Private - safe CAR stream wrapper
  # ---------------------------------------------------------------------------

  # Wraps CAR.stream_decode/1 in a Stream.resource that manually drives the
  # inner enumerable one item at a time via its suspension continuation.
  #
  # The key property: when the downstream halts early (Stream.take, etc.),
  # the cleanup function calls the continuation with {:halt, nil}, which
  # triggers DASL.CAR.StreamDecoder.finish/1. That function raises a
  # RuntimeError if its internal buffer is non-empty (as it will be mid-stream).
  # We catch that specific raise here so callers never see it.
  #
  # Genuine parse errors (truncated file, CID mismatch) still propagate because
  # they originate in next_fun, not in the cleanup path.
  @spec safe_car_decode(Enumerable.t()) :: Enumerable.t()
  defp safe_car_decode(chunk_stream) do
    # The step function suspends after every item, giving us a continuation
    # we can call directly: cont.({:cont, nil}) to advance, cont.({:halt, nil})
    # to clean up. The continuation already has the reducer baked in from the
    # initial Enumerable.reduce call so subsequent steps just call it directly.
    step = fn item, _ -> {:suspend, item} end

    Stream.resource(
      fn ->
        case Enumerable.reduce(CAR.stream_decode(chunk_stream), {:cont, nil}, step) do
          {:suspended, item, cont} -> {item, cont}
          _ -> :done
        end
      end,
      fn
        :done ->
          {:halt, :done}

        {item, cont} ->
          next =
            case cont.({:cont, nil}) do
              {:suspended, next_item, next_cont} -> {next_item, next_cont}
              _ -> :done
            end

          {[item], next}
      end,
      fn
        :done ->
          :ok

        {_item, cont} ->
          try do
            cont.({:halt, nil})
          rescue
            RuntimeError -> :ok
          end
      end
    )
  end

  # ---------------------------------------------------------------------------
  # Private - stream_car incremental reducer
  # ---------------------------------------------------------------------------

  # State fields:
  #   commit_cid   - the root CID from the CAR header (first root)
  #   cid_to_path  - %{record_value_CID => "collection/rkey"}, built as MST
  #                  node blocks arrive in pre-order
  #   halted       - true after an unrecoverable error; blocks are skipped but
  #                  the source stream is always allowed to finish naturally

  @spec reduce_car_item(DASL.CAR.StreamDecoder.stream_item(), map()) :: {list(), map()}
  defp reduce_car_item(_item, %{halted: true} = state), do: {[], state}

  defp reduce_car_item({:header, _version, [root | _]}, state) do
    {[], %{state | commit_cid: root}}
  end

  defp reduce_car_item({:header, _version, []}, state) do
    {[{:error, :no_root}], %{state | halted: true}}
  end

  defp reduce_car_item({:block, cid, data}, %{commit_cid: commit_cid} = state) do
    cond do
      cid == commit_cid ->
        case Commit.decode(data) do
          {:ok, commit, _} -> {[{:commit, commit}], state}
          {:error, reason} -> {[{:error, reason}], %{state | halted: true}}
        end

      cid.codec == :drisl ->
        case Node.decode(data) do
          {:ok, node} ->
            full_keys = MST.Node.keys(node)

            cid_to_path =
              node.entries
              |> Enum.zip(full_keys)
              |> Enum.reduce(state.cid_to_path, fn {entry, key}, acc ->
                Map.put(acc, entry.value.bytes, key)
              end)

            {[], %{state | cid_to_path: cid_to_path}}

          {:error, :decode, _} ->
            emit_record_block(cid, data, state)
        end

      true ->
        emit_record_block(cid, data, state)
    end
  end

  @spec emit_record_block(CID.t(), binary(), map()) :: {list(), map()}
  defp emit_record_block(cid, data, state) do
    case Map.fetch(state.cid_to_path, cid.bytes) do
      :error ->
        {[{:error, :unresolvable_record, cid}], %{state | halted: true}}

      {:ok, key} ->
        case DRISL.decode(data) do
          {:error, _} ->
            {[], state}

          {:ok, record, _} ->
            case String.split(key, "/", parts: 2) do
              [collection, rkey] ->
                {[{:record, %Path{collection: collection, rkey: rkey}, record}], state}

              _ ->
                {[], state}
            end
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private - CAR export helpers
  # ---------------------------------------------------------------------------

  # Encodes a CARv1 binary with the commit block guaranteed to be first,
  # followed by the MST and record blocks in pre-order. This ensures the output
  # is in streamable order per the spec and is correctly processed by stream_car/1.
  @spec encode_car_ordered(CID.t(), binary(), ordered_acc()) ::
          {:ok, binary()} | {:error, atom()}
  defp encode_car_ordered(commit_cid, commit_bytes, {blocks_map, rev_order}) do
    alias Varint.LEB128

    # Build each block as an iolist: [leb128_length, cid_bytes, data].
    # Accumulating iolists avoids binary copying at each step; a single
    # :erlang.iolist_to_binary at the end does one allocation.
    encode_block_io = fn %CID{bytes: cid_bytes}, data ->
      [LEB128.encode(byte_size(cid_bytes) + byte_size(data)), cid_bytes, data]
    end

    with {:ok, header_bin} <-
           DRISL.encode(%{"version" => 1, "roots" => [commit_cid]}) do
      header_io = [LEB128.encode(byte_size(header_bin)), header_bin]
      commit_io = encode_block_io.(commit_cid, commit_bytes)

      # rev_order was built by prepending, so reverse to get pre-order sequence.
      rest_io =
        rev_order
        |> Enum.reverse()
        |> Enum.map(fn cid -> encode_block_io.(cid, Map.fetch!(blocks_map, cid)) end)

      {:ok, :erlang.iolist_to_binary([header_io, commit_io, rest_io])}
    end
  end

  # Returns {blocks_map, ordered_cids} where ordered_cids preserves pre-order
  # insertion sequence. This is necessary because Elixir maps do not preserve
  # insertion order - iterating a map in encode_car_ordered/3 would lose the
  # pre-order block sequencing required for streamable CARs.
  @type ordered_acc() :: {%{CID.t() => binary()}, [CID.t()]}

  @spec collect_ordered_blocks(Tree.t(), %{CID.t() => binary()}) ::
          {:ok, ordered_acc()} | {:error, atom()}
  defp collect_ordered_blocks(%Tree{root: nil}, _record_blocks) do
    empty = Node.empty()
    {:ok, bytes} = Node.encode(empty)
    cid = CID.compute(bytes, :drisl)
    {:ok, {%{cid => bytes}, [cid]}}
  end

  defp collect_ordered_blocks(%Tree{root: root, store: store}, record_blocks) do
    collect_node_blocks(store, root, record_blocks, {%{}, []})
  end

  @spec collect_node_blocks(Store.t(), CID.t(), %{CID.t() => binary()}, ordered_acc()) ::
          {:ok, ordered_acc()} | {:error, atom()}
  defp collect_node_blocks(store, cid, record_blocks, {map, order}) do
    with {:ok, node} <- Store.get(store, cid),
         {:ok, node_bytes} <- Node.encode(node) do
      acc = {Map.put(map, cid, node_bytes), [cid | order]}

      Enum.reduce_while(build_preorder_steps(node), {:ok, acc}, fn step, {:ok, {map, order}} ->
        case step do
          {:node, child_cid} ->
            case collect_node_blocks(store, child_cid, record_blocks, {map, order}) do
              {:ok, acc} -> {:cont, {:ok, acc}}
              err -> {:halt, err}
            end

          {:record, record_cid} ->
            case Map.fetch(record_blocks, record_cid) do
              {:ok, bytes} ->
                {:cont, {:ok, {Map.put(map, record_cid, bytes), [record_cid | order]}}}

              :error ->
                {:cont, {:ok, {map, order}}}
            end
        end
      end)
    else
      {:error, :not_found} -> {:error, :missing_node}
      {:error, :encode, reason} -> {:error, reason}
    end
  end

  @spec build_preorder_steps(Node.t()) :: list()
  defp build_preorder_steps(node) do
    left_steps = if node.left, do: [{:node, node.left}], else: []

    entry_steps =
      Enum.flat_map(node.entries, fn entry ->
        right_steps = if entry.right, do: [{:node, entry.right}], else: []
        [{:record, entry.value} | right_steps]
      end)

    left_steps ++ entry_steps
  end

  # ---------------------------------------------------------------------------
  # Private - CAR import helpers
  # ---------------------------------------------------------------------------

  @spec car_root_cid(CAR.t()) :: {:ok, CID.t()} | {:error, :no_root}
  defp car_root_cid(%CAR{roots: [cid | _]}), do: {:ok, cid}
  defp car_root_cid(%CAR{roots: []}), do: {:error, :no_root}

  @spec decode_commit_block(%{CID.t() => binary()}, CID.t()) ::
          {:ok, Commit.t()} | {:error, atom()}
  defp decode_commit_block(blocks, cid) do
    with {:ok, bytes} <- fetch_block(blocks, cid),
         {:ok, commit, _rest} <- Commit.decode(bytes) do
      {:ok, commit}
    end
  end

  @spec build_tree_from_car(%{CID.t() => binary()}, CID.t(), CID.t() | nil) ::
          {:ok, Tree.t(), %{CID.t() => binary()}} | {:error, atom()}
  defp build_tree_from_car(blocks, commit_cid, mst_root) do
    result =
      Enum.reduce_while(blocks, {:ok, Store.Memory.new(), %{}}, fn {cid, data},
                                                                   {:ok, store, rec_blocks} ->
        cond do
          cid == commit_cid ->
            {:cont, {:ok, store, rec_blocks}}

          cid.codec == :drisl ->
            case Node.decode(data) do
              {:ok, node} ->
                {:cont, {:ok, Store.put(store, cid, node), rec_blocks}}

              {:error, :decode, _reason} ->
                {:cont, {:ok, store, Map.put(rec_blocks, cid, data)}}
            end

          true ->
            {:cont, {:ok, store, Map.put(rec_blocks, cid, data)}}
        end
      end)

    with {:ok, store, record_blocks} <- result do
      {:ok, Tree.from_root(mst_root, store), record_blocks}
    end
  end

  # ---------------------------------------------------------------------------
  # Private - misc
  # ---------------------------------------------------------------------------

  @spec mst_root_cid(Tree.t()) :: CID.t()
  defp mst_root_cid(%Tree{root: nil}) do
    empty = Node.empty()
    {:ok, bytes} = Node.encode(empty)
    CID.compute(bytes, :drisl)
  end

  defp mst_root_cid(%Tree{root: cid}), do: cid

  @spec fetch_block(%{CID.t() => binary()}, CID.t()) :: {:ok, binary()} | {:error, :not_found}
  defp fetch_block(blocks, cid) do
    case Map.fetch(blocks, cid) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, :not_found}
    end
  end
end

defimpl Inspect, for: Atex.Repo do
  import Inspect.Algebra

  def inspect(%Atex.Repo{commit: nil, blocks: blocks}, _opts) do
    concat(["#Atex.Repo<uncommitted records=", Integer.to_string(map_size(blocks)), ">"])
  end

  def inspect(%Atex.Repo{commit: commit, blocks: blocks}, _opts) do
    concat([
      "#Atex.Repo<",
      commit.did,
      " rev=",
      commit.rev,
      " records=",
      Integer.to_string(map_size(blocks)),
      ">"
    ])
  end
end
