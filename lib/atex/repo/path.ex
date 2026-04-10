defmodule Atex.Repo.Path do
  @moduledoc """
  A validated AT Protocol repository path - a `collection/rkey` pair.

  Repo paths identify individual records within a repository. They always have
  exactly two segments separated by a single `/`:

  - **collection** - a valid NSID string (e.g. `"app.bsky.feed.post"`)
  - **rkey** - a record key string (e.g. `"3jzfcijpj2z2a"`, `"self"`,
    `"example.com"`)

  ## Character constraints

  Collection segments follow NSID syntax: alphanumeric characters and periods
  (`A-Za-z0-9.`), at least two period-separated components.

  Record keys allow: `A-Za-z0-9 . - _ : ~` (per
  [spec](https://atproto.com/specs/record-key)), with a minimum length of 1
  and the values `"."` and `".."` disallowed.

  ## Usage

      iex> {:ok, path} = Atex.Repo.Path.new("app.bsky.feed.post", "3jzfcijpj2z2a")
      iex> to_string(path)
      "app.bsky.feed.post/3jzfcijpj2z2a"

      iex> {:ok, path} = Atex.Repo.Path.from_string("app.bsky.actor.profile/self")
      iex> path.collection
      "app.bsky.actor.profile"
      iex> path.rkey
      "self"

  ## `String.Chars` and interpolation

  `Atex.Repo.Path` implements `String.Chars`, so paths can be used directly
  in string interpolation and anywhere a string path is expected:

      iex> path = Atex.Repo.Path.new!("app.bsky.feed.post", "3jzfcijpj2z2a")
      iex> "Record at \#{path}"
      "Record at app.bsky.feed.post/3jzfcijpj2z2a"

  ATProto spec: https://atproto.com/specs/repository#repository-paths
  """

  use TypedStruct

  # Collection: NSID - only A-Za-z0-9 and periods, must have at least one dot
  # (i.e. at least two components). Case-sensitive, no leading/trailing dots.
  @collection_re ~r/^[a-zA-Z][a-zA-Z0-9]*(?:\.[a-zA-Z][a-zA-Z0-9]*)+$/

  # Record key: A-Za-z0-9 .-_:~ only, min 1 char.
  @rkey_re ~r/^[A-Za-z0-9.\-_:~]+$/

  @reserved_rkeys [~c".", ~c".."]

  typedstruct enforce: true do
    @typedoc "A validated AT Protocol repository path (collection + rkey)."
    field :collection, String.t()
    field :rkey, String.t()
  end

  @doc """
  Builds a validated `%Atex.Repo.Path{}` from a collection and record key.

  Returns `{:error, :invalid_collection}` if the collection is not a valid
  NSID, or `{:error, :invalid_rkey}` if the record key contains disallowed
  characters or is a reserved value (`.` or `..`).

  ## Examples

      iex> Atex.Repo.Path.new("app.bsky.feed.post", "3jzfcijpj2z2a")
      {:ok, %Atex.Repo.Path{collection: "app.bsky.feed.post", rkey: "3jzfcijpj2z2a"}}

      iex> Atex.Repo.Path.new("not-an-nsid", "self")
      {:error, :invalid_collection}

      iex> Atex.Repo.Path.new("app.bsky.feed.post", "..")
      {:error, :invalid_rkey}

      iex> Atex.Repo.Path.new("app.bsky.feed.post", "bad key!")
      {:error, :invalid_rkey}

  """
  @spec new(String.t(), String.t()) :: {:ok, t()} | {:error, :invalid_collection | :invalid_rkey}
  def new(collection, rkey) when is_binary(collection) and is_binary(rkey) do
    with :ok <- validate_collection(collection),
         :ok <- validate_rkey(rkey) do
      {:ok, %__MODULE__{collection: collection, rkey: rkey}}
    end
  end

  @doc """
  Builds a validated `%Atex.Repo.Path{}`, raising on invalid input.

  ## Examples

      iex> Atex.Repo.Path.new!("app.bsky.feed.post", "3jzfcijpj2z2a")
      %Atex.Repo.Path{collection: "app.bsky.feed.post", rkey: "3jzfcijpj2z2a"}

  """
  @spec new!(String.t(), String.t()) :: t()
  def new!(collection, rkey) do
    case new(collection, rkey) do
      {:ok, path} -> path
      {:error, reason} -> raise ArgumentError, "invalid repo path: #{reason}"
    end
  end

  @doc """
  Parses a `"collection/rkey"` string into a validated `%Atex.Repo.Path{}`.

  Returns `{:error, :invalid_path}` if the string does not contain exactly one
  `/`, or if either segment is invalid.

  ## Examples

      iex> Atex.Repo.Path.from_string("app.bsky.feed.post/3jzfcijpj2z2a")
      {:ok, %Atex.Repo.Path{collection: "app.bsky.feed.post", rkey: "3jzfcijpj2z2a"}}

      iex> Atex.Repo.Path.from_string("no-slash")
      {:error, :invalid_path}

      iex> Atex.Repo.Path.from_string("a/b/c")
      {:error, :invalid_path}

  """
  @spec from_string(String.t()) ::
          {:ok, t()} | {:error, :invalid_path | :invalid_collection | :invalid_rkey}
  def from_string(string) when is_binary(string) do
    case String.split(string, "/") do
      [collection, rkey] when collection != "" and rkey != "" ->
        case new(collection, rkey) do
          {:ok, _} = ok -> ok
          {:error, _} = err -> err
        end

      _ ->
        {:error, :invalid_path}
    end
  end

  @doc """
  Parses a `"collection/rkey"` string into a validated `%Atex.Repo.Path{}`,
  raising on invalid input.

  ## Examples

      iex> Atex.Repo.Path.from_string!("app.bsky.feed.post/3jzfcijpj2z2a")
      %Atex.Repo.Path{collection: "app.bsky.feed.post", rkey: "3jzfcijpj2z2a"}

  """
  @spec from_string!(String.t()) :: t()
  def from_string!(string) when is_binary(string) do
    case from_string(string) do
      {:ok, path} -> path
      {:error, reason} -> raise ArgumentError, "invalid repo path: #{reason}"
    end
  end

  @doc """
  Converts the path to its canonical `"collection/rkey"` string form.

  ## Examples

      iex> path = Atex.Repo.Path.new!("app.bsky.feed.post", "3jzfcijpj2z2a")
      iex> Atex.Repo.Path.to_string(path)
      "app.bsky.feed.post/3jzfcijpj2z2a"

  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{collection: collection, rkey: rkey}), do: "#{collection}/#{rkey}"

  @doc """
  Sigil for constructing a validated `%Atex.Repo.Path{}` from a literal string.

  Raises `ArgumentError` if the string is not a valid `"collection/rkey"` path.
  To use this sigil, import `Atex.Repo.Path`.

  ## Examples

      iex> import Atex.Repo.Path
      iex> ~PATH"app.bsky.feed.post/3jzfcijpj2z2a"
      %Atex.Repo.Path{collection: "app.bsky.feed.post", rkey: "3jzfcijpj2z2a"}

  """
  @spec sigil_PATH(String.t(), list()) :: t()
  def sigil_PATH(string, _) when is_binary(string), do: from_string!(string)

  # ---------------------------------------------------------------------------
  # Private validators
  # ---------------------------------------------------------------------------

  @spec validate_collection(String.t()) :: :ok | {:error, :invalid_collection}
  defp validate_collection(collection) do
    if Regex.match?(@collection_re, collection),
      do: :ok,
      else: {:error, :invalid_collection}
  end

  @spec validate_rkey(String.t()) :: :ok | {:error, :invalid_rkey}
  defp validate_rkey(rkey) do
    cond do
      rkey == "" -> {:error, :invalid_rkey}
      String.to_charlist(rkey) in @reserved_rkeys -> {:error, :invalid_rkey}
      not Regex.match?(@rkey_re, rkey) -> {:error, :invalid_rkey}
      true -> :ok
    end
  end
end

defimpl String.Chars, for: Atex.Repo.Path do
  def to_string(path), do: Atex.Repo.Path.to_string(path)
end

defimpl Inspect, for: Atex.Repo.Path do
  def inspect(path, _opts) do
    ~s'~PATH"#{path}"'
  end
end
