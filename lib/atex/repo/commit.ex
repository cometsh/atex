defmodule Atex.Repo.Commit do
  @moduledoc """
  The signed commit object at the top of an AT Protocol repository.

  A commit binds together:

  - The account DID that owns the repository.
  - A CID link (`data`) to the root of the MST that holds all records.
  - A monotonically-increasing revision (`rev`) in TID string format, used as
    a logical clock.
  - A `prev` link to the previous commit (virtually always `nil` in v3 repos,
    but the field must be present in the CBOR object).
  - A cryptographic `sig` over the DRISL CBOR encoding of the unsigned commit.

  ## Signing a commit

  The signing convention follows the AT Protocol repository spec:

  1. Build an unsigned commit (all fields except `sig`).
  2. Encode it with `encode_unsigned/1` to get the DRISL CBOR bytes.
  3. SHA-256 hash the bytes, then ECDSA-sign the *hash* with the account's
     signing key.
  4. Store the raw (DER-encoded) signature bytes in `sig`.

  `sign/2` performs steps 2–4 in one call. Verification with `verify/2`
  reverses the process using a public key.

  ## CID computation

  The CID for a commit is computed from the DRISL CBOR encoding of the **signed**
  commit object (with `sig` present), using the `:drisl` codec.

  ## Wire format

  Map keys follow the AT Protocol specification field names:

  - `"did"` - account DID string
  - `"version"` - integer `3`
  - `"data"` - CID link to MST root
  - `"rev"` - TID string
  - `"prev"` - CID link or `nil`
  - `"sig"` - raw ECDSA signature bytes (absent from the unsigned map)

  ATProto spec: https://atproto.com/specs/repository#commit-objects
  """

  use TypedStruct
  alias Atex.Crypto
  alias DASL.{CID, DRISL}

  @version 3

  typedstruct enforce: true do
    @typedoc "A v3 AT Protocol repository commit."

    field :did, String.t()
    field :version, pos_integer(), default: @version
    field :data, CID.t()
    field :rev, String.t()
    field :prev, CID.t() | nil
    field :sig, binary() | nil
  end

  @doc """
  Builds an unsigned commit struct from the given fields.

  `sig` is set to `nil`.

  ## Options

  - `:did` (required) - the account DID string
  - `:data` (required) - `DASL.CID` pointing to the MST root
  - `:rev` (required) - TID string used as the logical clock
  - `:prev` - `DASL.CID` pointing to the previous commit, or `nil` (default)

  ## Examples

      iex> data_cid = DASL.CID.compute("data", :drisl)
      iex> commit = Atex.Repo.Commit.new(
      ...>   did: "did:plc:example",
      ...>   data: data_cid,
      ...>   rev: "3jzfcijpj2z2a"
      ...> )
      iex> commit.version
      3
      iex> commit.sig
      nil

  """
  @spec new(keyword()) :: t()
  def new(fields) do
    %__MODULE__{
      did: Keyword.fetch!(fields, :did),
      version: @version,
      data: Keyword.fetch!(fields, :data),
      rev: Keyword.fetch!(fields, :rev),
      prev: Keyword.get(fields, :prev, nil),
      sig: nil
    }
  end

  @doc """
  Serializes the commit **without** the `sig` field as DRISL CBOR.

  This is the payload that is hashed and signed. The `sig` field is omitted
  entirely from the map, as required by the spec.

  ## Examples

      iex> data_cid = DASL.CID.compute("data", :drisl)
      iex> commit = Atex.Repo.Commit.new(did: "did:plc:e", data: data_cid, rev: "3jzfcijpj2z2a")
      iex> {:ok, bin} = Atex.Repo.Commit.encode_unsigned(commit)
      iex> is_binary(bin)
      true

  """
  @spec encode_unsigned(t()) :: {:ok, binary()} | {:error, atom()}
  def encode_unsigned(%__MODULE__{} = commit) do
    commit |> to_unsigned_map() |> DRISL.encode()
  end

  @doc """
  Serializes a signed commit (including `sig`) as DRISL CBOR.

  Returns `{:error, :unsigned}` if `sig` is `nil`.

  ## Examples

      iex> data_cid = DASL.CID.compute("data", :drisl)
      iex> commit = Atex.Repo.Commit.new(did: "did:plc:e", data: data_cid, rev: "3jzfcijpj2z2a")
      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, signed} = Atex.Repo.Commit.sign(commit, jwk)
      iex> {:ok, bin} = Atex.Repo.Commit.encode(signed)
      iex> is_binary(bin)
      true

  """
  @spec encode(t()) :: {:ok, binary()} | {:error, :unsigned | atom()}
  def encode(%__MODULE__{sig: nil}), do: {:error, :unsigned}

  def encode(%__MODULE__{} = commit) do
    commit |> to_signed_map() |> DRISL.encode()
  end

  @doc """
  Decodes a DRISL CBOR binary into a `%Atex.Repo.Commit{}`.

  Accepts both signed (with `"sig"`) and unsigned (without `"sig"`) payloads.

  ## Examples

      iex> data_cid = DASL.CID.compute("data", :drisl)
      iex> commit = Atex.Repo.Commit.new(did: "did:plc:e", data: data_cid, rev: "3jzfcijpj2z2a")
      iex> {:ok, bin} = Atex.Repo.Commit.encode_unsigned(commit)
      iex> {:ok, decoded, ""} = Atex.Repo.Commit.decode(bin)
      iex> decoded.did
      "did:plc:e"

  """
  @spec decode(binary()) :: {:ok, t(), binary()} | {:error, atom()}
  def decode(binary) when is_binary(binary) do
    with {:ok, map, rest} <- DRISL.decode(binary),
         {:ok, commit} <- from_map(map) do
      {:ok, commit, rest}
    end
  end

  @doc """
  Signs an unsigned commit with the given private key.

  Encodes the unsigned commit as DRISL CBOR and signs the bytes using
  `Atex.Crypto.sign/2` (SHA-256 ECDSA, low-S normalized DER output).

  Returns `{:error, :already_signed}` if `sig` is already present.

  ## Examples

      iex> data_cid = DASL.CID.compute("data", :drisl)
      iex> commit = Atex.Repo.Commit.new(did: "did:plc:e", data: data_cid, rev: "3jzfcijpj2z2a")
      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, signed} = Atex.Repo.Commit.sign(commit, jwk)
      iex> is_binary(signed.sig)
      true

  """
  @spec sign(t(), JOSE.JWK.t()) :: {:ok, t()} | {:error, :already_signed | atom()}
  def sign(%__MODULE__{sig: sig}, _jwk) when not is_nil(sig), do: {:error, :already_signed}

  def sign(%__MODULE__{} = commit, jwk) do
    with {:ok, payload} <- encode_unsigned(commit),
         {:ok, sig} <- Crypto.sign(payload, jwk) do
      {:ok, %{commit | sig: sig}}
    end
  end

  @doc """
  Verifies the signature of a signed commit against the given public key.

  Returns `:ok` or `{:error, reason}`.

  ## Examples

      iex> data_cid = DASL.CID.compute("data", :drisl)
      iex> commit = Atex.Repo.Commit.new(did: "did:plc:e", data: data_cid, rev: "3jzfcijpj2z2a")
      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, signed} = Atex.Repo.Commit.sign(commit, jwk)
      iex> Atex.Repo.Commit.verify(signed, JOSE.JWK.to_public(jwk))
      :ok

  """
  @spec verify(t(), JOSE.JWK.t()) :: :ok | {:error, :unsigned | atom()}
  def verify(%__MODULE__{sig: nil}, _jwk), do: {:error, :unsigned}

  def verify(%__MODULE__{sig: sig} = commit, jwk) do
    with {:ok, payload} <- encode_unsigned(commit) do
      Crypto.verify(payload, sig, jwk)
    end
  end

  @doc """
  Computes the CID of a signed commit.

  The CID is derived from the DRISL CBOR encoding of the **signed** commit
  object, using the `:drisl` codec (blessed CID format).

  Returns `{:error, :unsigned}` if `sig` is `nil`.

  ## Examples

      iex> data_cid = DASL.CID.compute("data", :drisl)
      iex> commit = Atex.Repo.Commit.new(did: "did:plc:e", data: data_cid, rev: "3jzfcijpj2z2a")
      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, signed} = Atex.Repo.Commit.sign(commit, jwk)
      iex> {:ok, cid} = Atex.Repo.Commit.cid(signed)
      iex> cid.codec
      :drisl

  """
  @spec cid(t()) :: {:ok, CID.t()} | {:error, :unsigned | atom()}
  def cid(%__MODULE__{sig: nil}), do: {:error, :unsigned}

  def cid(%__MODULE__{} = commit) do
    with {:ok, bytes} <- encode(commit) do
      {:ok, CID.compute(bytes, :drisl)}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec to_unsigned_map(t()) :: map()
  defp to_unsigned_map(%__MODULE__{} = c) do
    %{
      "did" => c.did,
      "version" => c.version,
      "data" => c.data,
      "rev" => c.rev,
      "prev" => c.prev
    }
  end

  @spec to_signed_map(t()) :: map()
  defp to_signed_map(%__MODULE__{} = c) do
    c
    |> to_unsigned_map()
    |> Map.put("sig", %CBOR.Tag{tag: :bytes, value: c.sig})
  end

  @spec from_map(map()) :: {:ok, t()} | {:error, atom()}
  defp from_map(map) when is_map(map) do
    with {:ok, did} <- fetch_string(map, "did"),
         {:ok, version} <- fetch_integer(map, "version"),
         {:ok, data} <- fetch_cid(map, "data"),
         {:ok, rev} <- fetch_string(map, "rev"),
         {:ok, prev} <- fetch_nullable_cid(map, "prev") do
      sig = extract_sig(Map.get(map, "sig"))

      {:ok,
       %__MODULE__{
         did: did,
         version: version,
         data: data,
         rev: rev,
         prev: prev,
         sig: sig
       }}
    end
  end

  defp from_map(_), do: {:error, :invalid_commit}

  @spec extract_sig(any()) :: binary() | nil
  defp extract_sig(%CBOR.Tag{tag: :bytes, value: bytes}) when is_binary(bytes), do: bytes
  defp extract_sig(bytes) when is_binary(bytes), do: bytes
  defp extract_sig(_), do: nil

  @spec fetch_string(map(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  defp fetch_string(map, key) do
    case Map.fetch(map, key) do
      {:ok, val} when is_binary(val) -> {:ok, val}
      {:ok, _} -> {:error, :invalid_commit}
      :error -> {:error, :missing_field}
    end
  end

  @spec fetch_integer(map(), String.t()) :: {:ok, integer()} | {:error, atom()}
  defp fetch_integer(map, key) do
    case Map.fetch(map, key) do
      {:ok, val} when is_integer(val) -> {:ok, val}
      {:ok, _} -> {:error, :invalid_commit}
      :error -> {:error, :missing_field}
    end
  end

  @spec fetch_cid(map(), String.t()) :: {:ok, CID.t()} | {:error, atom()}
  defp fetch_cid(map, key) do
    case Map.fetch(map, key) do
      {:ok, %CID{} = cid} -> {:ok, cid}
      {:ok, _} -> {:error, :invalid_commit}
      :error -> {:error, :missing_field}
    end
  end

  @spec fetch_nullable_cid(map(), String.t()) :: {:ok, CID.t() | nil} | {:error, atom()}
  defp fetch_nullable_cid(map, key) do
    case Map.fetch(map, key) do
      {:ok, %CID{} = cid} -> {:ok, cid}
      {:ok, nil} -> {:ok, nil}
      {:ok, _} -> {:error, :invalid_commit}
      :error -> {:ok, nil}
    end
  end
end
