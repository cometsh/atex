defmodule Atex.NSID do
  @moduledoc """
  Represents an AT Protocol Namespaced Identifier (NSID).

  An NSID consists of a **domain authority** (reversed domain name, e.g.
  `"app.bsky.feed"`) and a **name** segment (e.g. `"post"`), optionally
  followed by a **fragment** (e.g. `"view"`), which is a Lexicon-level concept.

  ## Structure

  - `authority` - the reversed-domain portion, e.g. `"app.bsky.feed"`
  - `name` - the final camelCase segment, e.g. `"post"`
  - `fragment` - optional fragment string, e.g. `"view"` (nil for plain NSIDs)

  ## Construction

      iex> Atex.NSID.new("app.bsky.feed.post")
      {:ok, ~NSID"app.bsky.feed.post"}

      iex> Atex.NSID.new("app.bsky.feed.post#view")
      {:ok, ~NSID"app.bsky.feed.post#view"}

      iex> Atex.NSID.new("invalid")
      {:error, :invalid_nsid}

      iex> Atex.NSID.new!("app.bsky.feed.post")
      ~NSID"app.bsky.feed.post"

  ## Sigil

  Use `~NSID"..."` for convenient literal construction. Raises `ArgumentError`
  at the call site if the string is not a valid NSID.

      import Atex.NSID, only: [sigil_NSID: 2]
      nsid = ~NSID"com.atproto.sync.getRecord"
  """

  @re ~r/^[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?:\.[a-zA-Z](?:[a-zA-Z0-9]{0,62})?)$/

  use TypedStruct

  typedstruct do
    field :authority, String.t(), enforce: true
    field :name, String.t(), enforce: true
    field :fragment, String.t() | nil
  end

  @doc """
  Returns the compiled NSID validation regex.

  Useful for embedding into schema validators.

  ## Examples

      iex> Atex.NSID.re()
      ~r/^[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?:\\.[a-zA-Z](?:[a-zA-Z0-9]{0,62})?)$/
  """
  @spec re() :: Regex.t()
  def re, do: @re

  @doc """
  Returns `true` if the given string is a syntactically valid NSID (without
  fragment), `false` otherwise.

  ## Examples

      iex> Atex.NSID.match?("app.bsky.feed.post")
      true

      iex> Atex.NSID.match?("invalid")
      false
  """
  @spec match?(String.t()) :: boolean()
  def match?(value), do: Regex.match?(@re, value)

  @doc """
  Parses a string into an `%Atex.NSID{}` struct.

  Accepts an optional `#fragment` suffix. Returns `{:error, :invalid_nsid}` if
  the base NSID portion is not syntactically valid.

  ## Examples

      iex> Atex.NSID.new("app.bsky.feed.post")
      {:ok, ~NSID"app.bsky.feed.post"}

      iex> Atex.NSID.new("app.bsky.feed.post#view")
      {:ok, ~NSID"app.bsky.feed.post#view"}

      iex> Atex.NSID.new("invalid")
      {:error, :invalid_nsid}
  """
  @spec new(String.t()) :: {:ok, t()} | {:error, :invalid_nsid}
  def new(string) when is_binary(string) do
    {base, fragment} = split_fragment(string)

    if match?(base) do
      {authority, name} = split_authority_name(base)
      {:ok, %__MODULE__{authority: authority, name: name, fragment: fragment}}
    else
      {:error, :invalid_nsid}
    end
  end

  @doc """
  Parses a string into an `%Atex.NSID{}` struct, raising `ArgumentError` on
  invalid input.

  ## Examples

      iex> Atex.NSID.new!("app.bsky.feed.post")
      ~NSID"app.bsky.feed.post"

      iex> Atex.NSID.new!("bad")
      ** (ArgumentError) invalid NSID: "bad"
  """
  @spec new!(String.t()) :: t()
  def new!(string) when is_binary(string) do
    case new(string) do
      {:ok, nsid} -> nsid
      {:error, :invalid_nsid} -> raise ArgumentError, "invalid NSID: #{inspect(string)}"
    end
  end

  @doc """
  Sigil for constructing an `%Atex.NSID{}` at runtime, raising `ArgumentError`
  for invalid input.

  ## Examples

      iex> import Atex.NSID, only: [sigil_NSID: 2]
      iex> ~NSID"app.bsky.feed.post"
      ~NSID"app.bsky.feed.post"
  """
  defmacro sigil_NSID({:<<>>, _meta, [string]}, []) when is_binary(string) do
    nsid = Atex.NSID.new!(string)

    quote do
      unquote(Macro.escape(nsid))
    end
  end

  defmacro sigil_NSID({:<<>>, _meta, _parts}, []) do
    quote do
      Atex.NSID.new!(
        unquote({:<<>>, [], [{:"::", [], [{:fragments, [], nil}, {:binary, [], nil}]}]})
      )
    end
  end

  @doc """
  Converts an `%Atex.NSID{}` to its canonical string representation.

  Includes the fragment if present.

  ## Examples

      iex> Atex.NSID.to_string(~NSID"app.bsky.feed.post")
      "app.bsky.feed.post"

      iex> Atex.NSID.to_string(~NSID"app.bsky.feed.post#view")
      "app.bsky.feed.post#view"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{authority: authority, name: name, fragment: nil}) do
    "#{authority}.#{name}"
  end

  def to_string(%__MODULE__{authority: authority, name: name, fragment: fragment}) do
    "#{authority}.#{name}##{fragment}"
  end

  @doc """
  Converts an `%Atex.NSID{}` to an Elixir module atom.

  The fragment is ignored; only the base NSID segments are used.

  ## Examples

      iex> Atex.NSID.to_atom(~NSID"app.bsky.feed.post")
      App.Bsky.Feed.Post

      iex> Atex.NSID.to_atom(~NSID"app.bsky.feed.post", false)
      :"Elixir.App.Bsky.Feed.Post"
  """
  @spec to_atom(t(), boolean()) :: atom()
  def to_atom(%__MODULE__{authority: authority, name: name}, fully_qualify \\ true) do
    parts =
      "#{authority}.#{name}"
      |> String.split(".")
      |> Enum.map(&Recase.to_pascal/1)

    parts =
      if fully_qualify do
        ["Elixir" | parts]
      else
        parts
      end

    parts
    |> Enum.join(".")
    |> String.to_atom()
  end

  @doc """
  Converts an `%Atex.NSID{}` to a `{module_atom, fragment_atom}` pair.

  The fragment defaults to `:main` when absent.

  ## Examples

      iex> Atex.NSID.to_atom_with_fragment(~NSID"app.bsky.feed.post")
      {App.Bsky.Feed.Post, :main}

      iex> Atex.NSID.to_atom_with_fragment(~NSID"app.bsky.feed.post#view")
      {App.Bsky.Feed.Post, :view}
  """
  @spec to_atom_with_fragment(t()) :: {atom(), atom()}
  def to_atom_with_fragment(%__MODULE__{fragment: nil} = nsid) do
    {to_atom(nsid), :main}
  end

  def to_atom_with_fragment(%__MODULE__{fragment: fragment} = nsid) do
    {to_atom(nsid), String.to_atom(fragment)}
  end

  @doc """
  Expands a possible fragment shorthand relative to this NSID.

  If `ref` starts with `"#"`, it is treated as a fragment shorthand and
  prefixed with the base NSID string. Otherwise `ref` is returned unchanged.

  ## Examples

      iex> Atex.NSID.expand_fragment_shorthand(~NSID"app.bsky.feed.post", "#view")
      "app.bsky.feed.post#view"

      iex> Atex.NSID.expand_fragment_shorthand(~NSID"app.bsky.feed.post", "com.example.other")
      "com.example.other"
  """
  @spec expand_fragment_shorthand(t(), String.t()) :: String.t()
  def expand_fragment_shorthand(%__MODULE__{} = nsid, ref) when is_binary(ref) do
    base = "#{nsid.authority}.#{nsid.name}"

    if String.starts_with?(ref, "#") do
      base <> ref
    else
      ref
    end
  end

  @doc """
  Returns the canonical Lexicon name for this NSID.

  Returns the plain NSID string when the fragment is `"main"` or `nil`, and
  `"nsid#fragment"` otherwise.

  ## Examples

      iex> Atex.NSID.canonical_name(~NSID"app.bsky.feed.post")
      "app.bsky.feed.post"

      iex> Atex.NSID.canonical_name(~NSID"app.bsky.feed.post#view")
      "app.bsky.feed.post#view"

      iex> Atex.NSID.canonical_name(%Atex.NSID{authority: "app.bsky.feed", name: "post", fragment: "main"})
      "app.bsky.feed.post"
  """
  @spec canonical_name(t()) :: String.t()
  def canonical_name(%__MODULE__{fragment: fragment} = nsid)
      when is_nil(fragment) or fragment == "main" do
    "#{nsid.authority}.#{nsid.name}"
  end

  def canonical_name(%__MODULE__{} = nsid) do
    "#{nsid.authority}.#{nsid.name}##{nsid.fragment}"
  end

  @doc """
  Returns the DNS authority domain for this NSID, as used for lexicon
  resolution via DNS TXT records.

  The authority domain is derived by reversing the authority segments and
  prepending `_lexicon.`.

  ## Examples

      iex> Atex.NSID.authority_domain(~NSID"app.bsky.feed.post")
      "_lexicon.feed.bsky.app"

      iex> Atex.NSID.authority_domain(~NSID"edu.university.dept.lab.blogging.getBlogPost")
      "_lexicon.blogging.lab.dept.university.edu"
  """
  @spec authority_domain(t()) :: String.t()
  def authority_domain(%__MODULE__{authority: authority}) do
    reversed =
      authority
      |> String.split(".")
      |> Enum.reverse()
      |> Enum.join(".")

    "_lexicon.#{reversed}"
  end

  # --- Private helpers ---

  defp split_fragment(string) do
    case String.split(string, "#", parts: 2) do
      [base, fragment] -> {base, fragment}
      [base] -> {base, nil}
    end
  end

  defp split_authority_name(base) do
    segments = String.split(base, ".")
    name = List.last(segments)
    authority = segments |> Enum.drop(-1) |> Enum.join(".")
    {authority, name}
  end

  defimpl String.Chars do
    def to_string(nsid), do: Atex.NSID.to_string(nsid)
  end

  defimpl Inspect do
    def inspect(%Atex.NSID{} = nsid, _opts) do
      "~NSID\"#{Atex.NSID.to_string(nsid)}\""
    end
  end
end
