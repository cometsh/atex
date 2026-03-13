defmodule Atex.DID.Document.VerificationMethodTest do
  use ExUnit.Case, async: true
  alias Atex.DID.Document.VerificationMethod

  # Spec example legacy K-256 key from https://atproto.com/specs/did#legacy-representation
  @legacy_k256_multibase "zQYEBzXeuTM9UR3rfvNag6L3RNAs5pQZyYPsomTsgQhsxLdEgCrPTLgFna8yqCnxPpNT7DBk6Ym3dgPKNu86vt9GR"
  # The same key in Multikey (compressed) format
  @multikey_k256 "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"

  describe "new/1 - Multikey format" do
    test "parses a Multikey verificationMethod into a JOSE.JWK" do
      assert {:ok, vm} =
               VerificationMethod.new(%{
                 "id" => "did:plc:abc123#atproto",
                 "type" => "Multikey",
                 "controller" => "did:plc:abc123",
                 "publicKeyMultibase" => @multikey_k256
               })

      assert vm.id == "did:plc:abc123#atproto"
      assert vm.type == "Multikey"
      assert vm.controller == "did:plc:abc123"
      assert %JOSE.JWK{} = vm.public_key_jwk
      {_, map} = JOSE.JWK.to_map(vm.public_key_jwk)
      assert map["crv"] == "secp256k1"
    end

    test "parses a P-256 Multikey" do
      p256_mk = "zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo"

      assert {:ok, vm} =
               VerificationMethod.new(%{
                 "id" => "#atproto",
                 "type" => "Multikey",
                 "controller" => "did:plc:abc123",
                 "publicKeyMultibase" => p256_mk
               })

      {_, map} = JOSE.JWK.to_map(vm.public_key_jwk)
      assert map["crv"] == "P-256"
    end
  end

  describe "new/1 - legacy uncompressed multibase format" do
    test "parses a legacy EcdsaSecp256k1VerificationKey2019 entry" do
      assert {:ok, vm} =
               VerificationMethod.new(%{
                 "id" => "#atproto",
                 "type" => "EcdsaSecp256k1VerificationKey2019",
                 "controller" => "did:plc:abc123",
                 "publicKeyMultibase" => @legacy_k256_multibase
               })

      assert %JOSE.JWK{} = vm.public_key_jwk
      {_, map} = JOSE.JWK.to_map(vm.public_key_jwk)
      assert map["crv"] == "secp256k1"
    end

    test "legacy and Multikey entries for the same key produce the same JWK" do
      {:ok, vm_legacy} =
        VerificationMethod.new(%{
          "id" => "#atproto",
          "type" => "EcdsaSecp256k1VerificationKey2019",
          "controller" => "did:plc:abc123",
          "publicKeyMultibase" => @legacy_k256_multibase
        })

      {:ok, vm_current} =
        VerificationMethod.new(%{
          "id" => "#atproto",
          "type" => "Multikey",
          "controller" => "did:plc:abc123",
          "publicKeyMultibase" => @multikey_k256
        })

      {_, legacy_map} = JOSE.JWK.to_map(vm_legacy.public_key_jwk)
      {_, current_map} = JOSE.JWK.to_map(vm_current.public_key_jwk)
      assert legacy_map["x"] == current_map["x"]
      assert legacy_map["y"] == current_map["y"]
    end

    test "parses a legacy EcdsaSecp256r1VerificationKey2019 entry" do
      priv = JOSE.JWK.generate_key({:ec, "P-256"})
      pub = JOSE.JWK.to_public(priv)
      {_, map} = JOSE.JWK.to_map(pub)

      x = Base.url_decode64!(map["x"], padding: false)
      y = Base.url_decode64!(map["y"], padding: false)
      uncompressed = <<0x04>> <> x <> y
      legacy_mb = Multiformats.Multibase.encode(uncompressed, :base58btc)

      assert {:ok, vm} =
               VerificationMethod.new(%{
                 "id" => "#atproto",
                 "type" => "EcdsaSecp256r1VerificationKey2019",
                 "controller" => "did:plc:abc123",
                 "publicKeyMultibase" => legacy_mb
               })

      {_, decoded_map} = JOSE.JWK.to_map(vm.public_key_jwk)
      assert decoded_map["x"] == map["x"]
      assert decoded_map["y"] == map["y"]
    end
  end

  describe "to_json/1" do
    test "emits Multikey format regardless of input format" do
      assert {:ok, vm} =
               VerificationMethod.new(%{
                 "id" => "#atproto",
                 "type" => "EcdsaSecp256k1VerificationKey2019",
                 "controller" => "did:plc:abc123",
                 "publicKeyMultibase" => @legacy_k256_multibase
               })

      json = VerificationMethod.to_json(vm)
      assert json["type"] == "Multikey"
      assert is_binary(json["publicKeyMultibase"])
      assert String.starts_with?(json["publicKeyMultibase"], "z")
      refute Map.has_key?(json, "publicKeyJwk")
    end

    test "round-trips Multikey -> to_json" do
      assert {:ok, vm} =
               VerificationMethod.new(%{
                 "id" => "did:plc:abc123#atproto",
                 "type" => "Multikey",
                 "controller" => "did:plc:abc123",
                 "publicKeyMultibase" => @multikey_k256
               })

      json = VerificationMethod.to_json(vm)
      assert json["publicKeyMultibase"] == @multikey_k256
    end

    test "omits publicKeyMultibase when no key is present" do
      vm = %VerificationMethod{
        id: "#atproto",
        type: "Multikey",
        controller: "did:plc:abc123",
        public_key_jwk: nil
      }

      json = VerificationMethod.to_json(vm)
      refute Map.has_key?(json, "publicKeyMultibase")
    end
  end

  describe "new/1 - error cases" do
    test "returns error when required field is missing" do
      assert {:error, _} =
               VerificationMethod.new(%{
                 "type" => "Multikey",
                 "controller" => "did:plc:abc123",
                 "publicKeyMultibase" => @multikey_k256
               })
    end
  end
end
