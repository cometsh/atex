defmodule Atex.CryptoTest do
  use ExUnit.Case, async: true
  alias Atex.Crypto
  doctest Crypto

  # ---------------------------------------------------------------------------
  # AT Protocol spec example keys (from https://atproto.com/specs/cryptography)
  # ---------------------------------------------------------------------------

  # P-256 compressed public key as multikey
  @p256_multikey "zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo"
  # secp256k1 compressed public key as multikey
  @k256_multikey "zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc"

  # ---------------------------------------------------------------------------
  # decode_did_key/1
  # ---------------------------------------------------------------------------

  describe "decode_did_key/1" do
    test "decodes a P-256 multikey into a JOSE JWK" do
      assert {:ok, jwk} = Crypto.decode_did_key(@p256_multikey)
      assert %JOSE.JWK{} = jwk
      {_, map} = JOSE.JWK.to_map(jwk)
      assert map["kty"] == "EC"
      assert map["crv"] == "P-256"
      assert is_binary(map["x"]) and map["x"] != ""
      assert is_binary(map["y"]) and map["y"] != ""
    end

    test "decodes a secp256k1 multikey into a JOSE JWK" do
      assert {:ok, jwk} = Crypto.decode_did_key(@k256_multikey)
      assert %JOSE.JWK{} = jwk
      {_, map} = JOSE.JWK.to_map(jwk)
      assert map["kty"] == "EC"
      assert map["crv"] == "secp256k1"
    end

    test "accepts a did:key: prefixed URI" do
      assert {:ok, jwk_bare} = Crypto.decode_did_key(@p256_multikey)
      assert {:ok, jwk_did} = Crypto.decode_did_key("did:key:" <> @p256_multikey)

      {_, map_bare} = JOSE.JWK.to_map(jwk_bare)
      {_, map_did} = JOSE.JWK.to_map(jwk_did)
      assert map_bare == map_did
    end

    test "accepts a full did:key secp256k1 URI" do
      assert {:ok, _jwk} = Crypto.decode_did_key("did:key:" <> @k256_multikey)
    end

    test "returns an error for an invalid multikey string" do
      assert {:error, :invalid_multikey} = Crypto.decode_did_key("not-a-valid-key")
    end

    test "returns an error for an unsupported curve codec" do
      # A well-formed multibase string that decodes to an unknown codec
      # Encode some random bytes with a non-key multicodec prefix
      raw = <<0x12, 32>> <> :crypto.strong_rand_bytes(32)
      bad_key = Multiformats.Multibase.encode(raw, :base58btc)
      assert {:error, _} = Crypto.decode_did_key(bad_key)
    end
  end

  # ---------------------------------------------------------------------------
  # encode_did_key/1
  # ---------------------------------------------------------------------------

  describe "encode_did_key/1" do
    test "encodes a P-256 JWK back to the canonical multikey" do
      {:ok, jwk} = Crypto.decode_did_key(@p256_multikey)
      assert {:ok, encoded} = Crypto.encode_did_key(jwk)
      assert encoded == @p256_multikey
    end

    test "encodes a secp256k1 JWK back to the canonical multikey" do
      {:ok, jwk} = Crypto.decode_did_key(@k256_multikey)
      assert {:ok, encoded} = Crypto.encode_did_key(jwk)
      assert encoded == @k256_multikey
    end

    test "produces a z-prefixed multibase string" do
      jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      assert {:ok, encoded} = Crypto.encode_did_key(jwk)
      assert String.starts_with?(encoded, "z")
    end

    test "strips private key component before encoding" do
      priv_jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      pub_jwk = JOSE.JWK.to_public(priv_jwk)

      assert {:ok, from_priv} = Crypto.encode_did_key(priv_jwk)
      assert {:ok, from_pub} = Crypto.encode_did_key(pub_jwk)
      assert from_priv == from_pub
    end

    test "as_did_key: false (default) returns bare multikey" do
      jwk = JOSE.JWK.generate_key({:ec, "P-256"})
      assert {:ok, mk} = Crypto.encode_did_key(jwk)
      refute String.starts_with?(mk, "did:key:")
    end

    test "as_did_key: true returns a did:key URI" do
      {:ok, jwk} = Crypto.decode_did_key(@p256_multikey)
      assert {:ok, did_key} = Crypto.encode_did_key(jwk, as_did_key: true)
      assert did_key == "did:key:" <> @p256_multikey
    end

    test "as_did_key: true works for secp256k1" do
      {:ok, jwk} = Crypto.decode_did_key(@k256_multikey)
      assert {:ok, did_key} = Crypto.encode_did_key(jwk, as_did_key: true)
      assert did_key == "did:key:" <> @k256_multikey
    end
  end

  # ---------------------------------------------------------------------------
  # encode_did_key/decode_did_key round-trip
  # ---------------------------------------------------------------------------

  describe "encode_did_key/decode_did_key round-trip" do
    test "round-trips a freshly generated P-256 key" do
      jwk = JOSE.JWK.generate_key({:ec, "P-256"}) |> JOSE.JWK.to_public()
      assert {:ok, mk} = Crypto.encode_did_key(jwk)
      assert {:ok, jwk2} = Crypto.decode_did_key(mk)

      {_, orig_map} = JOSE.JWK.to_map(jwk)
      {_, decoded_map} = JOSE.JWK.to_map(jwk2)
      assert orig_map == decoded_map
    end

    test "round-trips a freshly generated secp256k1 key" do
      jwk = JOSE.JWK.generate_key({:ec, "secp256k1"}) |> JOSE.JWK.to_public()
      assert {:ok, mk} = Crypto.encode_did_key(jwk)
      assert {:ok, jwk2} = Crypto.decode_did_key(mk)

      {_, orig_map} = JOSE.JWK.to_map(jwk)
      {_, decoded_map} = JOSE.JWK.to_map(jwk2)
      assert orig_map == decoded_map
    end
  end

  # ---------------------------------------------------------------------------
  # sign/2
  # ---------------------------------------------------------------------------

  describe "sign/2" do
    test "returns a DER-encoded binary for a P-256 key" do
      priv = JOSE.JWK.generate_key({:ec, "P-256"})
      assert {:ok, sig} = Crypto.sign("payload", priv)
      assert is_binary(sig)
      # DER SEQUENCE tag
      assert <<0x30, _::binary>> = sig
    end

    test "returns a DER-encoded binary for a secp256k1 key" do
      priv = JOSE.JWK.generate_key({:ec, "secp256k1"})
      assert {:ok, sig} = Crypto.sign("payload", priv)
      assert is_binary(sig)
      assert <<0x30, _::binary>> = sig
    end

    test "produces a low-S signature for P-256" do
      p256_n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
      priv = JOSE.JWK.generate_key({:ec, "P-256"})

      Enum.each(1..20, fn _ ->
        {:ok, sig} = Crypto.sign("test", priv)

        <<0x30, _tl, 0x02, r_len, _r::binary-size(r_len), 0x02, s_len, s::binary-size(s_len)>> =
          sig

        s_int = :binary.decode_unsigned(s)
        assert s_int <= div(p256_n, 2), "expected low-S but got high-S"
      end)
    end

    test "produces a low-S signature for secp256k1" do
      k256_n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
      priv = JOSE.JWK.generate_key({:ec, "secp256k1"})

      Enum.each(1..20, fn _ ->
        {:ok, sig} = Crypto.sign("test", priv)

        <<0x30, _tl, 0x02, r_len, _r::binary-size(r_len), 0x02, s_len, s::binary-size(s_len)>> =
          sig

        s_int = :binary.decode_unsigned(s)
        assert s_int <= div(k256_n, 2), "expected low-S but got high-S"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # verify/3
  # ---------------------------------------------------------------------------

  describe "verify/3" do
    test "returns :ok for a valid P-256 signature" do
      priv = JOSE.JWK.generate_key({:ec, "P-256"})
      pub = JOSE.JWK.to_public(priv)
      {:ok, sig} = Crypto.sign("hello world", priv)

      assert :ok = Crypto.verify("hello world", sig, pub)
    end

    test "returns :ok for a valid secp256k1 signature" do
      priv = JOSE.JWK.generate_key({:ec, "secp256k1"})
      pub = JOSE.JWK.to_public(priv)
      {:ok, sig} = Crypto.sign("hello world", priv)

      assert :ok = Crypto.verify("hello world", sig, pub)
    end

    test "returns :ok when verifying against the private key directly" do
      priv = JOSE.JWK.generate_key({:ec, "P-256"})
      {:ok, sig} = Crypto.sign("payload", priv)

      assert :ok = Crypto.verify("payload", sig, priv)
    end

    test "returns {:error, :invalid_signature} for a tampered payload" do
      priv = JOSE.JWK.generate_key({:ec, "P-256"})
      pub = JOSE.JWK.to_public(priv)
      {:ok, sig} = Crypto.sign("original", priv)

      assert {:error, :invalid_signature} = Crypto.verify("tampered", sig, pub)
    end

    test "returns {:error, :invalid_signature} for a wrong key" do
      priv_a = JOSE.JWK.generate_key({:ec, "P-256"})
      priv_b = JOSE.JWK.generate_key({:ec, "P-256"})
      pub_b = JOSE.JWK.to_public(priv_b)
      {:ok, sig} = Crypto.sign("payload", priv_a)

      assert {:error, :invalid_signature} = Crypto.verify("payload", sig, pub_b)
    end

    test "returns {:error, :invalid_signature} for a corrupted signature" do
      priv = JOSE.JWK.generate_key({:ec, "P-256"})
      pub = JOSE.JWK.to_public(priv)
      {:ok, sig} = Crypto.sign("payload", priv)

      corrupted = :binary.replace(sig, <<0x02>>, <<0x00>>, [:global])
      assert {:error, :invalid_signature} = Crypto.verify("payload", corrupted, pub)
    end

    test "verifies a signature produced from a decoded multikey" do
      # Simulate the atproto flow: decode a public key from a DID document,
      # then verify a payload signed by whoever controls that key.
      priv = JOSE.JWK.generate_key({:ec, "P-256"})
      {:ok, mk} = Crypto.encode_did_key(priv)
      {:ok, decoded_pub} = Crypto.decode_did_key(mk)

      {:ok, sig} = Crypto.sign("atproto payload", priv)
      assert :ok = Crypto.verify("atproto payload", sig, decoded_pub)
    end
  end

  # ---------------------------------------------------------------------------
  # sign/verify symmetry across curves
  # ---------------------------------------------------------------------------

  describe "sign/verify symmetry" do
    for curve <- ["P-256", "secp256k1"] do
      test "#{curve}: sign then verify succeeds" do
        priv = JOSE.JWK.generate_key({:ec, unquote(curve)})
        pub = JOSE.JWK.to_public(priv)
        payload = :crypto.strong_rand_bytes(128)

        {:ok, sig} = Crypto.sign(payload, priv)
        assert :ok = Crypto.verify(payload, sig, pub)
      end
    end
  end
end
