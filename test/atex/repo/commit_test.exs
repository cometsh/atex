defmodule Atex.Repo.CommitTest do
  use ExUnit.Case, async: true

  alias Atex.Repo.Commit
  alias DASL.CID

  @did "did:plc:example"
  @rev "3jzfcijpj2z2a"

  defp data_cid, do: CID.compute("mst root", :drisl)

  defp unsigned_commit do
    Commit.new(did: @did, data: data_cid(), rev: @rev)
  end

  defp p256_jwk, do: JOSE.JWK.generate_key({:ec, "P-256"})
  defp k256_jwk, do: JOSE.JWK.generate_key({:ec, "secp256k1"})

  # ---------------------------------------------------------------------------
  # new/1
  # ---------------------------------------------------------------------------

  describe "new/1" do
    test "sets version to 3" do
      assert unsigned_commit().version == 3
    end

    test "sets sig to nil" do
      assert unsigned_commit().sig == nil
    end

    test "sets prev to nil by default" do
      assert unsigned_commit().prev == nil
    end

    test "accepts an explicit prev CID" do
      prev = CID.compute("prev commit", :drisl)
      commit = Commit.new(did: @did, data: data_cid(), rev: @rev, prev: prev)
      assert commit.prev == prev
    end
  end

  # ---------------------------------------------------------------------------
  # encode_unsigned/1 + decode/1 round-trip
  # ---------------------------------------------------------------------------

  describe "encode_unsigned/1 and decode/1" do
    test "produces valid DRISL bytes" do
      assert {:ok, bin} = Commit.encode_unsigned(unsigned_commit())
      assert is_binary(bin)
    end

    test "round-trips unsigned commit" do
      commit = unsigned_commit()
      {:ok, bin} = Commit.encode_unsigned(commit)
      {:ok, decoded, rest} = Commit.decode(bin)

      assert rest == ""
      assert decoded.did == commit.did
      assert decoded.version == commit.version
      assert decoded.data == commit.data
      assert decoded.rev == commit.rev
      assert decoded.prev == commit.prev
      assert decoded.sig == nil
    end

    test "does not include sig in unsigned bytes" do
      jwk = p256_jwk()
      {:ok, signed} = Commit.sign(unsigned_commit(), jwk)

      {:ok, unsigned_bytes} = Commit.encode_unsigned(signed)
      {:ok, decoded, _} = Commit.decode(unsigned_bytes)

      assert decoded.sig == nil
    end
  end

  # ---------------------------------------------------------------------------
  # sign/2
  # ---------------------------------------------------------------------------

  describe "sign/2" do
    test "produces a binary signature (P-256)" do
      {:ok, signed} = Commit.sign(unsigned_commit(), p256_jwk())
      assert is_binary(signed.sig)
      assert byte_size(signed.sig) > 0
    end

    test "produces a binary signature (secp256k1)" do
      {:ok, signed} = Commit.sign(unsigned_commit(), k256_jwk())
      assert is_binary(signed.sig)
    end

    test "returns error when already signed" do
      {:ok, signed} = Commit.sign(unsigned_commit(), p256_jwk())
      assert {:error, :already_signed} = Commit.sign(signed, p256_jwk())
    end
  end

  # ---------------------------------------------------------------------------
  # verify/2
  # ---------------------------------------------------------------------------

  describe "verify/2" do
    test "accepts a valid signature (P-256)" do
      jwk = p256_jwk()
      {:ok, signed} = Commit.sign(unsigned_commit(), jwk)
      assert :ok = Commit.verify(signed, JOSE.JWK.to_public(jwk))
    end

    test "accepts a valid signature (secp256k1)" do
      jwk = k256_jwk()
      {:ok, signed} = Commit.sign(unsigned_commit(), jwk)
      assert :ok = Commit.verify(signed, JOSE.JWK.to_public(jwk))
    end

    test "rejects signature from a different key" do
      jwk_a = p256_jwk()
      jwk_b = p256_jwk()
      {:ok, signed} = Commit.sign(unsigned_commit(), jwk_a)
      assert {:error, _} = Commit.verify(signed, JOSE.JWK.to_public(jwk_b))
    end

    test "rejects unsigned commit" do
      assert {:error, :unsigned} = Commit.verify(unsigned_commit(), p256_jwk())
    end

    test "rejects tampered data field" do
      jwk = p256_jwk()
      {:ok, signed} = Commit.sign(unsigned_commit(), jwk)
      tampered = %{signed | data: CID.compute("tampered", :drisl)}
      assert {:error, _} = Commit.verify(tampered, JOSE.JWK.to_public(jwk))
    end
  end

  # ---------------------------------------------------------------------------
  # encode/1 (signed)
  # ---------------------------------------------------------------------------

  describe "encode/1" do
    test "returns error for unsigned commit" do
      assert {:error, :unsigned} = Commit.encode(unsigned_commit())
    end

    test "produces DRISL bytes for a signed commit" do
      jwk = p256_jwk()
      {:ok, signed} = Commit.sign(unsigned_commit(), jwk)
      assert {:ok, bin} = Commit.encode(signed)
      assert is_binary(bin)
    end

    test "round-trips signed commit" do
      jwk = p256_jwk()
      {:ok, signed} = Commit.sign(unsigned_commit(), jwk)
      {:ok, bin} = Commit.encode(signed)
      {:ok, decoded, _} = Commit.decode(bin)

      assert decoded.did == signed.did
      assert decoded.sig == signed.sig
      assert decoded.data == signed.data
    end
  end

  # ---------------------------------------------------------------------------
  # cid/1
  # ---------------------------------------------------------------------------

  describe "cid/1" do
    test "returns error for unsigned commit" do
      assert {:error, :unsigned} = Commit.cid(unsigned_commit())
    end

    test "returns a CID with :drisl codec" do
      jwk = p256_jwk()
      {:ok, signed} = Commit.sign(unsigned_commit(), jwk)
      {:ok, cid} = Commit.cid(signed)
      assert cid.codec == :drisl
    end

    test "is stable - same commit produces the same CID" do
      jwk = p256_jwk()
      {:ok, signed} = Commit.sign(unsigned_commit(), jwk)
      {:ok, cid1} = Commit.cid(signed)
      {:ok, cid2} = Commit.cid(signed)
      assert cid1 == cid2
    end

    test "changes when the data field changes" do
      jwk = p256_jwk()
      {:ok, signed_a} = Commit.sign(unsigned_commit(), jwk)

      commit_b = Commit.new(did: @did, data: CID.compute("other mst", :drisl), rev: @rev)
      {:ok, signed_b} = Commit.sign(commit_b, jwk)

      {:ok, cid_a} = Commit.cid(signed_a)
      {:ok, cid_b} = Commit.cid(signed_b)
      assert cid_a != cid_b
    end
  end
end
