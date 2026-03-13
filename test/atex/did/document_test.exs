defmodule Atex.DID.DocumentTest do
  use ExUnit.Case, async: true
  alias Atex.DID.Document
  alias Atex.DID.Document.{Service, VerificationMethod}

  @p256_multikey "zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo"

  @valid_doc %{
    "@context" => ["https://www.w3.org/ns/did/v1"],
    "id" => "did:plc:abc123",
    "alsoKnownAs" => ["at://alice.example.com"],
    "verificationMethod" => [
      %{
        "id" => "did:plc:abc123#atproto",
        "type" => "Multikey",
        "controller" => "did:plc:abc123",
        "publicKeyMultibase" => @p256_multikey
      }
    ],
    "service" => [
      %{
        "id" => "did:plc:abc123#atproto_pds",
        "type" => "AtprotoPersonalDataServer",
        "serviceEndpoint" => "https://pds.example.com"
      }
    ]
  }

  describe "new/1" do
    test "parses a complete document" do
      assert {:ok, doc} = Document.new(@valid_doc)
      assert doc.id == "did:plc:abc123"
      assert doc.also_known_as == ["at://alice.example.com"]
      assert [%VerificationMethod{}] = doc.verification_method
      assert [%Service{}] = doc.service
    end

    test "converts verification_method public keys to JWK" do
      assert {:ok, doc} = Document.new(@valid_doc)
      [vm] = doc.verification_method
      assert %JOSE.JWK{} = vm.public_key_jwk
    end

    test "accepts documents with no optional fields" do
      assert {:ok, doc} =
               Document.new(%{
                 "@context" => ["https://www.w3.org/ns/did/v1"],
                 "id" => "did:plc:abc123"
               })

      assert doc.id == "did:plc:abc123"
      assert is_nil(doc.verification_method) or doc.verification_method == []
    end

    test "returns error when required @context is missing" do
      assert {:error, _} = Document.new(%{"id" => "did:plc:abc123"})
    end

    test "drops unparseable verification_method entries silently" do
      doc_with_bad_vm =
        Map.put(@valid_doc, "verificationMethod", [
          %{"type" => "Multikey"},
          %{
            "id" => "did:plc:abc123#atproto",
            "type" => "Multikey",
            "controller" => "did:plc:abc123",
            "publicKeyMultibase" => @p256_multikey
          }
        ])

      assert {:ok, doc} = Document.new(doc_with_bad_vm)
      assert length(doc.verification_method) == 1
    end
  end

  describe "validate_for_atproto/2" do
    test "returns :ok for a valid document" do
      assert {:ok, doc} = Document.new(@valid_doc)
      assert :ok = Document.validate_for_atproto(doc, "did:plc:abc123")
    end

    test "returns {:error, :id_mismatch} when id does not match" do
      assert {:ok, doc} = Document.new(@valid_doc)
      assert {:error, :id_mismatch} = Document.validate_for_atproto(doc, "did:plc:other")
    end

    test "returns {:error, :no_signing_key} when atproto vm is missing" do
      doc_no_key = Map.put(@valid_doc, "verificationMethod", [])
      assert {:ok, doc} = Document.new(doc_no_key)
      assert {:error, :no_signing_key} = Document.validate_for_atproto(doc, "did:plc:abc123")
    end

    test "returns {:error, :invalid_pds} when PDS service is missing" do
      doc_no_pds = Map.put(@valid_doc, "service", [])
      assert {:ok, doc} = Document.new(doc_no_pds)
      assert {:error, :invalid_pds} = Document.validate_for_atproto(doc, "did:plc:abc123")
    end

    test "returns {:error, :invalid_pds} for PDS with a path component" do
      doc_bad_pds =
        Map.put(@valid_doc, "service", [
          %{
            "id" => "did:plc:abc123#atproto_pds",
            "type" => "AtprotoPersonalDataServer",
            "serviceEndpoint" => "https://pds.example.com/path"
          }
        ])

      assert {:ok, doc} = Document.new(doc_bad_pds)
      assert {:error, :invalid_pds} = Document.validate_for_atproto(doc, "did:plc:abc123")
    end
  end

  describe "get_atproto_handle/1" do
    test "returns the handle from alsoKnownAs" do
      assert {:ok, doc} = Document.new(@valid_doc)
      assert Document.get_atproto_handle(doc) == "alice.example.com"
    end

    test "returns nil when alsoKnownAs is nil" do
      assert {:ok, doc} = Document.new(Map.delete(@valid_doc, "alsoKnownAs"))
      assert is_nil(Document.get_atproto_handle(doc))
    end

    test "returns nil when no at:// URI is present" do
      doc_no_handle = Map.put(@valid_doc, "alsoKnownAs", ["https://example.com"])
      assert {:ok, doc} = Document.new(doc_no_handle)
      assert is_nil(Document.get_atproto_handle(doc))
    end

    test "returns the first valid at:// handle" do
      doc_multi =
        Map.put(@valid_doc, "alsoKnownAs", [
          "https://example.com",
          "at://first.example.com",
          "at://second.example.com"
        ])

      assert {:ok, doc} = Document.new(doc_multi)
      assert Document.get_atproto_handle(doc) == "first.example.com"
    end
  end

  describe "get_pds_endpoint/1" do
    test "returns the PDS endpoint" do
      assert {:ok, doc} = Document.new(@valid_doc)
      assert Document.get_pds_endpoint(doc) == "https://pds.example.com"
    end

    test "returns nil when no PDS service is present" do
      assert {:ok, doc} = Document.new(Map.put(@valid_doc, "service", []))
      assert is_nil(Document.get_pds_endpoint(doc))
    end
  end

  describe "get_atproto_signing_key/1" do
    test "returns the signing key as a JOSE.JWK" do
      assert {:ok, doc} = Document.new(@valid_doc)
      assert %JOSE.JWK{} = Document.get_atproto_signing_key(doc)
    end

    test "returns nil when no atproto vm is present" do
      assert {:ok, doc} = Document.new(Map.put(@valid_doc, "verificationMethod", []))
      assert is_nil(Document.get_atproto_signing_key(doc))
    end
  end

  describe "to_json/1" do
    test "produces camelCase keys" do
      assert {:ok, doc} = Document.new(@valid_doc)
      json = Document.to_json(doc)

      assert json["id"] == "did:plc:abc123"
      assert json["alsoKnownAs"] == ["at://alice.example.com"]
      assert [vm_json] = json["verificationMethod"]
      assert vm_json["type"] == "Multikey"
      assert [svc_json] = json["service"]
      assert svc_json["serviceEndpoint"] == "https://pds.example.com"

      refute Map.has_key?(json, "also_known_as")
      refute Map.has_key?(json, "verification_method")
      refute Map.has_key?(json, "service_endpoint")
    end

    test "omits nil optional fields" do
      assert {:ok, doc} =
               Document.new(%{
                 "@context" => ["https://www.w3.org/ns/did/v1"],
                 "id" => "did:plc:minimal"
               })

      json = Document.to_json(doc)
      refute Map.has_key?(json, "alsoKnownAs")
      refute Map.has_key?(json, "verificationMethod")
      refute Map.has_key?(json, "service")
      refute Map.has_key?(json, "controller")
    end

    test "verification methods in to_json are valid for re-parsing" do
      assert {:ok, doc} = Document.new(@valid_doc)
      json = Document.to_json(doc)
      assert {:ok, _doc2} = Document.new(json)
    end
  end
end
