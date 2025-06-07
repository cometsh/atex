defmodule Atex.AtURI do
  @moduledoc """
  Struct and helper functions for manipulating `at://` URIs, which identify
  specific records within the AT Protocol. For more information on the URI
  scheme, refer to the ATProto spec: https://atproto.com/specs/at-uri-scheme.

  This module only supports the restricted URI syntax used for the Lexicon
  `at-uri` type, with no support for query strings or fragments. If/when the
  full syntax gets widespread use, this module will expand to accomodate them.

  Both URIs using DIDs and handles ("example.com") are supported.
  """

  use TypedStruct

  @did ~S"did:(?:plc|web):[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]"
  @handle ~S"(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
  @nsid ~S"[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?:\.[a-zA-Z](?:[a-zA-Z0-9]{0,62})?)"

  @authority "(?<authority>(?:#{@did})|(?:#{@handle}))"
  @collection "(?<collection>#{@nsid})"
  @rkey "(?<rkey>[a-zA-Z0-9.-_:~]{1,512})"

  @re ~r"^at://#{@authority}(?:/#{@collection}(?:/#{@rkey})?)?$"

  typedstruct do
    field :authority, String.t(), enforce: true
    field :collection, String.t() | nil
    field :rkey, String.t() | nil
  end

  @doc """
  Create a new AtURI struct from a string by matching it against the regex.

  Returns `{:ok, aturi}` if a valid `at://` URI is given, otherwise it will return `:error`.

  ## Examples

      iex> Atex.AtURI.new("at://did:plc:44ybard66vv44zksje25o7dz/app.bsky.feed.post/3jwdwj2ctlk26")
      {:ok, %Atex.AtURI{
        rkey: "3jwdwj2ctlk26",
        collection: "app.bsky.feed.post",
        authority: "did:plc:44ybard66vv44zksje25o7dz"
      }}

      iex> Atex.AtURI.new("at:invalid/malformed")
      :error

  Partial URIs pointing to a collection without a record key, or even just a given authority, are also supported:

      iex> Atex.AtURI.new("at://ovyerus.com/sh.comet.v0.feed.track")
      {:ok, %Atex.AtURI{
        rkey: nil,
        collection: "sh.comet.v0.feed.track",
        authority: "ovyerus.com"
      }}

      iex> Atex.AtURI.new("at://did:web:comet.sh")
      {:ok, %Atex.AtURI{
        rkey: nil,
        collection: nil,
        authority: "did:web:comet.sh"
      }}
  """
  @spec new(String.t()) :: {:ok, t()} | :error
  def new(string) when is_binary(string) do
    # TODO: test different ways to get a good error from regex on which part failed match?
    case Regex.named_captures(@re, string) do
      %{} = captures -> {:ok, from_named_captures(captures)}
      nil -> :error
    end
  end

  @doc """
  The same as `new/1` but raises an `ArgumentError` if an invalid string is given.

  ## Examples

      iex> Atex.AtURI.new!("at://did:plc:44ybard66vv44zksje25o7dz/app.bsky.feed.post/3jwdwj2ctlk26")
      %Atex.AtURI{
        rkey: "3jwdwj2ctlk26",
        collection: "app.bsky.feed.post",
        authority: "did:plc:44ybard66vv44zksje25o7dz"
      }

      iex> Atex.AtURI.new!("at:invalid/malformed")
      ** (ArgumentError) Malformed at:// URI
  """
  @spec new!(String.t()) :: t()
  def new!(string) when is_binary(string) do
    case new(string) do
      {:ok, uri} -> uri
      :error -> raise ArgumentError, message: "Malformed at:// URI"
    end
  end

  @doc """
  Check if a string is a valid `at://` URI.

  ## Examples

      iex> Atex.AtURI.match?("at://did:plc:44ybard66vv44zksje25o7dz/app.bsky.feed.post/3jwdwj2ctlk26")
      true

      iex> Atex.AtURI.match?("at://did:web:comet.sh")
      true

      iex> Atex.AtURI.match?("at://ovyerus.com/sh.comet.v0.feed.track")
      true

      iex> Atex.AtURI.match?("gobbledy gook")
      false
  """
  @spec match?(String.t()) :: boolean()
  def match?(string), do: Regex.match?(@re, string)

  @doc """
  Format an `Atex.AtURI` to the canonical string representation.

  Also available via the `String.Chars` protocol.

  ## Examples

      iex> aturi = %Atex.AtURI{
      ...>   rkey: "3jwdwj2ctlk26",
      ...>   collection: "app.bsky.feed.post",
      ...>   authority: "did:plc:44ybard66vv44zksje25o7dz"
      ...> }
      iex> Atex.AtURI.to_string(aturi)
      "at://did:plc:44ybard66vv44zksje25o7dz/app.bsky.feed.post/3jwdwj2ctlk26"

      iex> aturi = %Atex.AtURI{authority: "did:web:comet.sh"}
      iex> to_string(aturi)
      "at://did:web:comet.sh"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = uri) do
    "at://#{uri.authority}/#{uri.collection}/#{uri.rkey}"
    |> String.trim_trailing("/")
  end

  defp from_named_captures(%{"authority" => authority, "collection" => "", "rkey" => ""}),
    do: %__MODULE__{authority: authority}

  defp from_named_captures(%{"authority" => authority, "collection" => collection, "rkey" => ""}),
    do: %__MODULE__{authority: authority, collection: collection}

  defp from_named_captures(%{
         "authority" => authority,
         "collection" => collection,
         "rkey" => rkey
       }),
       do: %__MODULE__{authority: authority, collection: collection, rkey: rkey}
end

defimpl String.Chars, for: Atex.AtURI do
  def to_string(%Atex.AtURI{} = uri), do: Atex.AtURI.to_string(uri)
end
