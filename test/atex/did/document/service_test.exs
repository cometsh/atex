defmodule Atex.DID.Document.ServiceTest do
  use ExUnit.Case, async: true
  alias Atex.DID.Document.Service
  doctest Service

  describe "new/1" do
    test "parses camelCase wire format" do
      assert {:ok, svc} =
               Service.new(%{
                 "id" => "#atproto_pds",
                 "type" => "AtprotoPersonalDataServer",
                 "serviceEndpoint" => "https://pds.example.com"
               })

      assert svc.id == "#atproto_pds"
      assert svc.type == "AtprotoPersonalDataServer"
      assert svc.service_endpoint == "https://pds.example.com"
    end

    test "parses snake_case keys" do
      assert {:ok, svc} =
               Service.new(%{
                 id: "#atproto_pds",
                 type: "AtprotoPersonalDataServer",
                 service_endpoint: "https://pds.example.com"
               })

      assert svc.service_endpoint == "https://pds.example.com"
    end

    test "accepts a list type" do
      assert {:ok, svc} =
               Service.new(%{
                 "id" => "#multi",
                 "type" => ["TypeA", "TypeB"],
                 "serviceEndpoint" => "https://example.com"
               })

      assert svc.type == ["TypeA", "TypeB"]
    end

    test "returns error when required field missing" do
      assert {:error, _} =
               Service.new(%{
                 "type" => "AtprotoPersonalDataServer",
                 "serviceEndpoint" => "https://pds.example.com"
               })
    end
  end

  describe "to_json/1" do
    test "produces camelCase map" do
      svc = %Service{
        id: "#atproto_pds",
        type: "AtprotoPersonalDataServer",
        service_endpoint: "https://pds.example.com"
      }

      json = Service.to_json(svc)
      assert json["id"] == "#atproto_pds"
      assert json["type"] == "AtprotoPersonalDataServer"
      assert json["serviceEndpoint"] == "https://pds.example.com"
      refute Map.has_key?(json, "service_endpoint")
    end

    test "round-trips new -> to_json" do
      input = %{
        "id" => "#atproto_pds",
        "type" => "AtprotoPersonalDataServer",
        "serviceEndpoint" => "https://pds.example.com"
      }

      assert {:ok, svc} = Service.new(input)
      assert Service.to_json(svc) == input
    end
  end
end
