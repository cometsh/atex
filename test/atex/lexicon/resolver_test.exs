defmodule Atex.Lexicon.ResolverTest do
  use ExUnit.Case, async: true

  import Mox

  alias Atex.Lexicon.Resolver
  alias Atex.Lexicon.Resolver.{MockDIDClient, MockDNSClient}
  alias Atex.NSID

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # NSID.authority_domain/1
  # ---------------------------------------------------------------------------

  describe "NSID.authority_domain/1" do
    test "converts a standard 4-part NSID" do
      assert {:ok, "_lexicon.feed.bsky.app"} = NSID.authority_domain("app.bsky.feed.post")
    end

    test "matches the spec example" do
      assert {:ok, "_lexicon.blogging.lab.dept.university.edu"} =
               NSID.authority_domain("edu.university.dept.lab.blogging.getBlogPost")
    end

    test "handles a minimal 3-segment NSID" do
      assert {:ok, "_lexicon.example.com"} = NSID.authority_domain("com.example.record")
    end

    test "handles NSIDs with numbers in segments" do
      assert {:ok, "_lexicon.v0.comet.sh"} = NSID.authority_domain("sh.comet.v0.feed")
    end

    test "returns error for a plain string without dots" do
      assert {:error, :invalid_nsid} = NSID.authority_domain("invalid")
    end

    test "returns error for an empty string" do
      assert {:error, :invalid_nsid} = NSID.authority_domain("")
    end

    test "returns error for a string with invalid characters" do
      assert {:error, :invalid_nsid} = NSID.authority_domain("not.valid!")
    end
  end

  # ---------------------------------------------------------------------------
  # Resolver.resolve/1 — invalid NSID (no network calls)
  # ---------------------------------------------------------------------------

  describe "resolve/1 with invalid NSID" do
    test "returns :invalid_nsid for a plain string" do
      assert {:error, :invalid_nsid} = Resolver.resolve("notannsid")
    end

    test "returns :invalid_nsid for an empty string" do
      assert {:error, :invalid_nsid} = Resolver.resolve("")
    end

    test "returns :invalid_nsid for a string with illegal characters" do
      assert {:error, :invalid_nsid} = Resolver.resolve("not.valid!")
    end
  end

  # ---------------------------------------------------------------------------
  # Resolver.resolve/1 — DNS failure
  # ---------------------------------------------------------------------------

  describe "resolve/1 with DNS failure" do
    test "returns :dns_resolution_failed when DNS returns no TXT records" do
      expect(MockDNSClient, :lookup_txt, fn "_lexicon.feed.bsky.app" -> [] end)

      assert {:error, :dns_resolution_failed} = Resolver.resolve("app.bsky.feed.post")
    end

    test "returns :dns_resolution_failed when TXT record has wrong prefix" do
      expect(MockDNSClient, :lookup_txt, fn "_lexicon.feed.bsky.app" ->
        [[~c"notadid=something"]]
      end)

      assert {:error, :dns_resolution_failed} = Resolver.resolve("app.bsky.feed.post")
    end

    test "returns :dns_resolution_failed when TXT value is not a valid DID" do
      expect(MockDNSClient, :lookup_txt, fn "_lexicon.feed.bsky.app" ->
        [[~c"did=notadidatall"]]
      end)

      assert {:error, :dns_resolution_failed} = Resolver.resolve("app.bsky.feed.post")
    end
  end

  # ---------------------------------------------------------------------------
  # Resolver.resolve/1 — DID resolution failure
  # ---------------------------------------------------------------------------

  describe "resolve/1 with DID resolution failure" do
    test "returns :did_resolution_failed when DID resolver errors" do
      expect(MockDNSClient, :lookup_txt, fn "_lexicon.feed.bsky.app" ->
        [[~c"did=did:plc:ewvi7nxzyoun6zhxrhs64oiz"]]
      end)

      expect(MockDIDClient, :resolve, fn "did:plc:ewvi7nxzyoun6zhxrhs64oiz" ->
        {:error, :not_found}
      end)

      assert {:error, :did_resolution_failed} = Resolver.resolve("app.bsky.feed.post")
    end
  end

  # ---------------------------------------------------------------------------
  # Resolver.resolve/1 — no PDS endpoint
  # ---------------------------------------------------------------------------

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @pds "https://pds.example.com"
  @nsid "app.bsky.feed.post"

  @did_doc_no_pds %Atex.DID.Document{
    "@context": ["https://www.w3.org/ns/did/v1"],
    id: @did
  }

  @did_doc_with_pds %Atex.DID.Document{
    "@context": ["https://www.w3.org/ns/did/v1"],
    id: @did,
    service: [
      %Atex.DID.Document.Service{
        id: "#{@did}#atproto_pds",
        type: "AtprotoPersonalDataServer",
        service_endpoint: @pds
      }
    ]
  }

  defp stub_dns_and_did(did_doc) do
    expect(MockDNSClient, :lookup_txt, fn "_lexicon.feed.bsky.app" ->
      [[~c"did=#{@did}"]]
    end)

    expect(MockDIDClient, :resolve, fn @did -> {:ok, did_doc} end)
  end

  describe "resolve/1 with no PDS endpoint" do
    test "returns :no_pds_endpoint when DID document has no PDS service" do
      stub_dns_and_did(@did_doc_no_pds)

      assert {:error, :no_pds_endpoint} = Resolver.resolve(@nsid)
    end
  end

  # ---------------------------------------------------------------------------
  # Resolver.resolve/1 — record fetch (Req.Test plug)
  # ---------------------------------------------------------------------------

  @lexicon_value %{
    "lexicon" => 1,
    "id" => @nsid,
    "defs" => %{
      "main" => %{
        "type" => "record",
        "key" => "tid",
        "record" => %{"type" => "object", "properties" => %{}}
      }
    }
  }

  defp stub_through_to_pds do
    expect(MockDNSClient, :lookup_txt, fn "_lexicon.feed.bsky.app" ->
      [[~c"did=#{@did}"]]
    end)

    expect(MockDIDClient, :resolve, fn @did -> {:ok, @did_doc_with_pds} end)
  end

  defp record_plug(record_resp) do
    fn conn ->
      case record_resp do
        :not_found ->
          Plug.Conn.send_resp(conn, 404, ~s({"error":"RecordNotFound"}))

        :missing_value ->
          Req.Test.json(conn, %{"uri" => "at://#{@did}/com.atproto.lexicon.schema/#{@nsid}"})

        value ->
          Req.Test.json(conn, %{
            "uri" => "at://#{@did}/com.atproto.lexicon.schema/#{@nsid}",
            "value" => value
          })
      end
    end
  end

  describe "resolve/1 — record fetch (Req.Test plug)" do
    test "returns the lexicon value map on success" do
      stub_through_to_pds()

      result = Resolver.resolve(@nsid, plug: record_plug(@lexicon_value))

      assert {:ok, lexicon} = result
      assert lexicon["id"] == @nsid
      assert lexicon["lexicon"] == 1
      assert is_map(lexicon["defs"])
    end

    test "returns :record_not_found when PDS returns 404" do
      stub_through_to_pds()

      assert {:error, :record_not_found} =
               Resolver.resolve(@nsid, plug: record_plug(:not_found))
    end

    test "returns :invalid_record when PDS response has no value key" do
      stub_through_to_pds()

      assert {:error, :invalid_record} =
               Resolver.resolve(@nsid, plug: record_plug(:missing_value))
    end
  end
end
