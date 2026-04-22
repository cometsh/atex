defmodule Atex.OAuth.DPoPTest do
  use ExUnit.Case, async: true

  alias Atex.OAuth.DPoP

  describe "create_dpop_token/4" do
    test "returns a compact JWT string" do
      key = JOSE.JWK.generate_key({:ec, "P-256"})
      request = Req.new(method: :get, url: "https://example.com/xrpc/foo")

      token = DPoP.create_dpop_token(key, request)

      assert is_binary(token)
      assert length(String.split(token, ".")) == 3
    end

    test "sets htm to uppercased HTTP method" do
      key = JOSE.JWK.generate_key({:ec, "P-256"})
      request = Req.new(method: :post, url: "https://example.com/xrpc/foo")

      token = DPoP.create_dpop_token(key, request)
      %{fields: claims} = JOSE.JWT.peek(token)

      assert claims["htm"] == "POST"
    end

    test "sets htu to URL without query string" do
      key = JOSE.JWK.generate_key({:ec, "P-256"})
      request = Req.new(method: :get, url: "https://example.com/xrpc/foo?bar=baz")

      token = DPoP.create_dpop_token(key, request)
      %{fields: claims} = JOSE.JWT.peek(token)

      assert claims["htu"] == "https://example.com/xrpc/foo"
    end

    test "includes nonce claim when provided" do
      key = JOSE.JWK.generate_key({:ec, "P-256"})
      request = Req.new(method: :get, url: "https://example.com/xrpc/foo")

      token = DPoP.create_dpop_token(key, request, "my-server-nonce")
      %{fields: claims} = JOSE.JWT.peek(token)

      assert claims["nonce"] == "my-server-nonce"
    end

    test "omits nonce claim when nil" do
      key = JOSE.JWK.generate_key({:ec, "P-256"})
      request = Req.new(method: :get, url: "https://example.com/xrpc/foo")

      token = DPoP.create_dpop_token(key, request, nil)
      %{fields: claims} = JOSE.JWT.peek(token)

      refute Map.has_key?(claims, "nonce")
    end

    test "merges extra claims into the JWT" do
      key = JOSE.JWK.generate_key({:ec, "P-256"})
      request = Req.new(method: :get, url: "https://example.com/xrpc/foo")

      token =
        DPoP.create_dpop_token(key, request, nil, %{iss: "https://bsky.social", ath: "abc123"})

      %{fields: claims} = JOSE.JWT.peek(token)

      assert claims["iss"] == "https://bsky.social"
      assert claims["ath"] == "abc123"
    end

    test "sets jti and iat" do
      key = JOSE.JWK.generate_key({:ec, "P-256"})
      request = Req.new(method: :get, url: "https://example.com/xrpc/foo")

      token = DPoP.create_dpop_token(key, request)
      %{fields: claims} = JOSE.JWT.peek(token)

      assert is_binary(claims["jti"])
      assert String.length(claims["jti"]) > 0
      assert is_integer(claims["iat"])
    end

    test "generates unique jti per call" do
      key = JOSE.JWK.generate_key({:ec, "P-256"})
      request = Req.new(method: :get, url: "https://example.com/xrpc/foo")

      token1 = DPoP.create_dpop_token(key, request)
      token2 = DPoP.create_dpop_token(key, request)
      %{fields: claims1} = JOSE.JWT.peek(token1)
      %{fields: claims2} = JOSE.JWT.peek(token2)

      refute claims1["jti"] == claims2["jti"]
    end
  end
end
