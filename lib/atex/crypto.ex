defmodule Atex.Crypto do
  @moduledoc """
  Cryptographic operations for the AT Protocol.

  Supports the two elliptic curves required by atproto:

  - `p256` - NIST P-256 / secp256r1 (JWK curve `"P-256"`)
  - `k256` - secp256k1 (JWK curve `"secp256k1"`)

  ## Key encoding

  Public keys are represented as `JOSE.JWK` structs throughout this module.
  The multikey / `did:key` encoding used in DID documents is the canonical
  external representation: a base58btc-encoded (multibase `z` prefix) binary
  consisting of a varint multicodec prefix followed by the 33-byte compressed
  EC point.

  ## Signing and verification

  Signatures are DER-encoded ECDSA byte sequences as produced by Erlang's
  `:public_key` application.  All produced signatures are normalised to the
  low-S form required by the atproto specification.
  """

  alias Multiformats.{Multibase, Multicodec}

  # Curve parameters

  # P-256 (secp256r1 / prime256v1)
  @p256_p 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF
  @p256_a @p256_p - 3
  @p256_b 0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B
  @p256_n 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
  @p256_oid {1, 2, 840, 10045, 3, 1, 7}

  # secp256k1
  @k256_p 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
  @k256_a 0
  @k256_b 7
  @k256_n 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
  @k256_oid {1, 3, 132, 0, 10}

  @typedoc """
  A multikey-encoded public key string, optionally prefixed with `did:key:`.

  Examples:

  - `"zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo"` (P-256 multikey)
  - `"did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc"` (K-256 did:key)
  """
  @type multikey :: String.t()

  @doc """
  Decodes a multikey or `did:key` string into a `JOSE.JWK` public key struct.

  Accepts both bare multikey strings (e.g. `"z..."`) and full `did:key` URIs
  (e.g. `"did:key:z..."`).  Supports P-256 (`p256-pub`) and secp256k1
  (`secp256k1-pub`) keys.

  ## Examples

      iex> {:ok, jwk} = Atex.Crypto.decode_did_key("zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo")
      iex> match?(%JOSE.JWK{}, jwk)
      true

      iex> {:ok, jwk} = Atex.Crypto.decode_did_key("did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc")
      iex> match?(%JOSE.JWK{}, jwk)
      true

      iex> Atex.Crypto.decode_did_key("not-a-valid-key")
      {:error, :invalid_multikey}
  """
  @spec decode_did_key(multikey()) :: {:ok, JOSE.JWK.t()} | {:error, term()}
  def decode_did_key(input) when is_binary(input) do
    multikey = strip_did_key_prefix(input)

    with {:ok, raw} <- multibase_decode(multikey),
         {:ok, codec, compressed} <- parse_multicodec(raw),
         {:ok, curve_params} <- curve_params_for_codec(codec),
         {:ok, x_bytes, y_bytes} <- decompress_point(compressed, curve_params) do
      jwk =
        JOSE.JWK.from_map(%{
          "kty" => "EC",
          "crv" => curve_params.jwk_crv,
          "x" => Base.url_encode64(x_bytes, padding: false),
          "y" => Base.url_encode64(y_bytes, padding: false)
        })

      {:ok, jwk}
    end
  end

  @doc """
  Encodes a `JOSE.JWK` public key as a multikey string.

  Accepts both public and private key JWKs; the private component is
  discarded.  Supports P-256 and secp256k1 keys.

  ## Options

  - `:as_did_key` — when `true`, prepends the `did:key:` URI scheme to the
    returned string.  Defaults to `false`.

  ## Examples

      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, mk} = Atex.Crypto.encode_did_key(jwk)
      iex> String.starts_with?(mk, "z")
      true

      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, mk} = Atex.Crypto.encode_did_key(jwk, as_did_key: true)
      iex> String.starts_with?(mk, "did:key:z")
      true
  """
  @spec encode_did_key(JOSE.JWK.t(), keyword()) :: {:ok, multikey()} | {:error, term()}
  def encode_did_key(jwk, opts \\ []) do
    as_did_key = Keyword.get(opts, :as_did_key, false)

    with {:ok, map} <- public_jwk_map(jwk),
         {:ok, codec_name} <- codec_name_for_crv(map["crv"]),
         {:ok, x_bytes} <- decode_jwk_coord(map["x"]),
         {:ok, y_bytes} <- decode_jwk_coord(map["y"]) do
      prefix = if rem(:binary.last(y_bytes), 2) == 0, do: 0x02, else: 0x03
      compressed = <<prefix>> <> x_bytes
      prefixed = Multicodec.encode!(compressed, codec_name)
      multikey = Multibase.encode(prefixed, :base58btc)

      result = if as_did_key, do: "did:key:" <> multikey, else: multikey
      {:ok, result}
    end
  end

  @doc """
  Verifies a DER-encoded ECDSA signature against a payload and a public key.

  The payload is hashed with SHA-256 internally before verification, matching
  the atproto signing convention.

  Returns `:ok` on success, or `{:error, :invalid_signature}` if the
  signature does not match.

  ## Examples

      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, sig} = Atex.Crypto.sign("hello", jwk)
      iex> Atex.Crypto.verify("hello", sig, JOSE.JWK.to_public(jwk))
      :ok

      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, sig} = Atex.Crypto.sign("hello", jwk)
      iex> Atex.Crypto.verify("tampered", sig, JOSE.JWK.to_public(jwk))
      {:error, :invalid_signature}
  """
  @spec verify(payload :: binary(), signature :: binary(), public_key :: JOSE.JWK.t()) ::
          :ok | {:error, term()}
  def verify(payload, signature, public_key) when is_binary(payload) and is_binary(signature) do
    {_meta, pub_record} = JOSE.JWK.to_public_key(public_key)
    {:ECPoint, pub_bytes} = elem(pub_record, 0)
    {:namedCurve, oid} = elem(pub_record, 1)
    digest = :crypto.hash(:sha256, payload)

    with {:ok, curve} <- oid_to_curve(oid) do
      if :crypto.verify(:ecdsa, :sha256, {:digest, digest}, signature, [pub_bytes, curve]) do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  rescue
    _ -> {:error, :invalid_signature}
  end

  @doc """
  Signs a payload with a private key, returning a low-S DER-encoded ECDSA
  signature.

  The payload is hashed with SHA-256 internally before signing, matching the
  atproto signing convention.

  ## Examples

      iex> jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      iex> {:ok, sig} = Atex.Crypto.sign("hello", jwk)
      iex> is_binary(sig)
      true
  """
  @spec sign(payload :: binary(), private_key :: JOSE.JWK.t()) ::
          {:ok, binary()} | {:error, term()}
  def sign(payload, private_key) when is_binary(payload) do
    {_meta, priv_record} = JOSE.JWK.to_key(private_key)
    {:ECPrivateKey, _ver, priv_bytes, {:namedCurve, oid}, _pub, _} = priv_record
    digest = :crypto.hash(:sha256, payload)

    with {:ok, curve} <- oid_to_curve(oid),
         {:ok, curve_order} <- curve_order_for_oid(oid) do
      signature = :crypto.sign(:ecdsa, :sha256, {:digest, digest}, [priv_bytes, curve])
      {:ok, normalize_low_s(signature, curve_order)}
    end
  rescue
    _ -> {:error, :sign_failed}
  end

  # Private helpers

  @spec strip_did_key_prefix(String.t()) :: String.t()
  defp strip_did_key_prefix("did:key:" <> rest), do: rest
  defp strip_did_key_prefix(input), do: input

  @spec multibase_decode(String.t()) :: {:ok, binary()} | {:error, :invalid_multikey}
  defp multibase_decode(multikey) do
    {:ok, Multibase.decode!(multikey)}
  rescue
    _ -> {:error, :invalid_multikey}
  end

  @spec parse_multicodec(binary()) ::
          {:ok, String.t(), binary()} | {:error, :invalid_multikey}
  defp parse_multicodec(raw) do
    {codec_meta, key_bytes} = Multicodec.parse_prefix(raw)

    if is_nil(codec_meta) do
      {:error, :invalid_multikey}
    else
      {:ok, codec_meta[:name], key_bytes}
    end
  rescue
    _ -> {:error, :invalid_multikey}
  end

  @spec curve_params_for_codec(String.t()) :: {:ok, map()} | {:error, :unsupported_curve}
  defp curve_params_for_codec("p256-pub") do
    {:ok,
     %{
       p: @p256_p,
       a: @p256_a,
       b: @p256_b,
       n: @p256_n,
       oid: @p256_oid,
       jwk_crv: "P-256"
     }}
  end

  defp curve_params_for_codec("secp256k1-pub") do
    {:ok,
     %{
       p: @k256_p,
       a: @k256_a,
       b: @k256_b,
       n: @k256_n,
       oid: @k256_oid,
       jwk_crv: "secp256k1"
     }}
  end

  defp curve_params_for_codec(_), do: {:error, :unsupported_curve}

  # Decompress a 33-byte EC point into separate x and y byte strings (32 bytes each).
  # Both P-256 and secp256k1 have field primes p ≡ 3 (mod 4), so the modular
  # square root is: y = rhs^((p+1)/4) mod p.
  @spec decompress_point(binary(), map()) ::
          {:ok, binary(), binary()} | {:error, :invalid_point}
  defp decompress_point(<<prefix, x_bytes::binary-size(32)>>, %{
         p: p,
         a: a,
         b: b
       })
       when prefix in [0x02, 0x03] do
    x = :binary.decode_unsigned(x_bytes)
    rhs = Integer.mod(x * x * x + a * x + b, p)
    exp = div(p + 1, 4)
    y_candidate = :binary.decode_unsigned(:crypto.mod_pow(rhs, exp, p))

    # Select the candidate matching the parity bit encoded in the prefix.
    # prefix 0x02 = even y, 0x03 = odd y.
    expected_parity = prefix - 2

    y =
      if rem(y_candidate, 2) == expected_parity do
        y_candidate
      else
        p - y_candidate
      end

    y_bytes = pad_to_32(:binary.encode_unsigned(y))
    {:ok, x_bytes, y_bytes}
  end

  defp decompress_point(_, _), do: {:error, :invalid_point}

  @spec pad_to_32(binary()) :: binary()
  defp pad_to_32(bin) do
    padding = 32 - byte_size(bin)
    :binary.copy(<<0>>, padding) <> bin
  end

  @spec public_jwk_map(JOSE.JWK.t()) :: {:ok, map()} | {:error, :unsupported_key}
  defp public_jwk_map(jwk) do
    {_, map} = jwk |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()

    if map["kty"] == "EC" and map["crv"] in ["P-256", "secp256k1"] do
      {:ok, map}
    else
      {:error, :unsupported_key}
    end
  rescue
    _ -> {:error, :unsupported_key}
  end

  @spec codec_name_for_crv(String.t()) :: {:ok, String.t()} | {:error, :unsupported_curve}
  defp codec_name_for_crv("P-256"), do: {:ok, "p256-pub"}
  defp codec_name_for_crv("secp256k1"), do: {:ok, "secp256k1-pub"}
  defp codec_name_for_crv(_), do: {:error, :unsupported_curve}

  @spec decode_jwk_coord(String.t() | nil) :: {:ok, binary()} | {:error, :invalid_key}
  defp decode_jwk_coord(nil), do: {:error, :invalid_key}

  defp decode_jwk_coord(b64url) do
    {:ok, Base.url_decode64!(b64url, padding: false)}
  rescue
    _ -> {:error, :invalid_key}
  end

  @spec oid_to_curve(tuple()) :: {:ok, atom()} | {:error, :unsupported_curve}
  defp oid_to_curve(@p256_oid), do: {:ok, :secp256r1}
  defp oid_to_curve(@k256_oid), do: {:ok, :secp256k1}
  defp oid_to_curve(_), do: {:error, :unsupported_curve}

  @spec curve_order_for_oid(tuple()) :: {:ok, pos_integer()} | {:error, :unsupported_curve}
  defp curve_order_for_oid(@p256_oid), do: {:ok, @p256_n}
  defp curve_order_for_oid(@k256_oid), do: {:ok, @k256_n}
  defp curve_order_for_oid(_), do: {:error, :unsupported_curve}

  # Normalise an ECDSA DER signature to low-S form.
  # If s > n/2, replace s with n - s and re-encode the DER sequence.
  @spec normalize_low_s(binary(), pos_integer()) :: binary()
  defp normalize_low_s(der_sig, curve_order) do
    with {:ok, r_bin, s_bin} <- parse_der_ecdsa(der_sig) do
      s = :binary.decode_unsigned(s_bin)

      if s <= div(curve_order, 2) do
        der_sig
      else
        new_s = curve_order - s
        new_s_bin = :binary.encode_unsigned(new_s)
        encode_der_ecdsa(r_bin, new_s_bin)
      end
    else
      _ -> der_sig
    end
  end

  # Parse a DER-encoded ECDSA signature: SEQUENCE { INTEGER r, INTEGER s }
  @spec parse_der_ecdsa(binary()) :: {:ok, binary(), binary()} | :error
  defp parse_der_ecdsa(
         <<0x30, _seq_len, 0x02, r_len, r::binary-size(r_len), 0x02, s_len,
           s::binary-size(s_len)>>
       ) do
    {:ok, r, s}
  end

  defp parse_der_ecdsa(_), do: :error

  # Re-encode r and s as a DER SEQUENCE { INTEGER r, INTEGER s }.
  # DER INTEGER encoding requires a leading 0x00 byte when the high bit is set.
  @spec encode_der_ecdsa(binary(), binary()) :: binary()
  defp encode_der_ecdsa(r_bin, s_bin) do
    r_der = der_integer(r_bin)
    s_der = der_integer(s_bin)
    seq_body = r_der <> s_der
    <<0x30, byte_size(seq_body)>> <> seq_body
  end

  @spec der_integer(binary()) :: binary()
  defp der_integer(<<high, _::binary>> = bin) when high >= 0x80 do
    payload = <<0x00>> <> bin
    <<0x02, byte_size(payload)>> <> payload
  end

  defp der_integer(bin) do
    <<0x02, byte_size(bin)>> <> bin
  end
end
