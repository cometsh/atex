defmodule Atex.OAuth.FlowTest do
  use ExUnit.Case, async: true

  alias Atex.OAuth.Flow

  describe "create_client_assertion/3" do
    setup do
      key = JOSE.JWK.generate_key({:ec, "P-256"})
      key = %{key | fields: Map.put(key.fields, "kid", "test-kid-123")}
      %{key: key}
    end

    test "returns a compact JWT string", %{key: key} do
      token =
        Flow.create_client_assertion(
          key,
          "https://example.com/client-metadata.json",
          "https://bsky.social"
        )

      assert is_binary(token)
      assert length(String.split(token, ".")) == 3
    end

    test "sets iss and sub to client_id", %{key: key} do
      client_id = "https://example.com/client-metadata.json"
      token = Flow.create_client_assertion(key, client_id, "https://bsky.social")

      %{fields: claims} = JOSE.JWT.peek(token)

      assert claims["iss"] == client_id
      assert claims["sub"] == client_id
    end

    test "sets aud to issuer", %{key: key} do
      issuer = "https://bsky.social"

      token =
        Flow.create_client_assertion(key, "https://example.com/client-metadata.json", issuer)

      %{fields: claims} = JOSE.JWT.peek(token)

      assert claims["aud"] == issuer
    end

    test "expires 60 seconds after iat", %{key: key} do
      token =
        Flow.create_client_assertion(
          key,
          "https://example.com/client-metadata.json",
          "https://bsky.social"
        )

      %{fields: claims} = JOSE.JWT.peek(token)

      assert claims["exp"] - claims["iat"] == 60
    end

    test "sets a non-empty jti", %{key: key} do
      token =
        Flow.create_client_assertion(
          key,
          "https://example.com/client-metadata.json",
          "https://bsky.social"
        )

      %{fields: claims} = JOSE.JWT.peek(token)

      assert is_binary(claims["jti"])
      assert String.length(claims["jti"]) > 0
    end

    test "produces a validly signed JWT", %{key: key} do
      token =
        Flow.create_client_assertion(
          key,
          "https://example.com/client-metadata.json",
          "https://bsky.social"
        )

      {true, %JOSE.JWT{}, _} = JOSE.JWT.verify(JOSE.JWK.to_public(key), token)
    end
  end
end
