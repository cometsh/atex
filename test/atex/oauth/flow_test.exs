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

  describe "telemetry" do
    setup do
      key = JOSE.JWK.generate_key({:ec, "P-256"})
      key = %{key | fields: Map.put(key.fields, "kid", "test-kid")}
      %{key: key}
    end

    test "create_authorization_url/5 emits authorization_url start/stop events", %{key: key} do
      ref = make_ref()

      :telemetry.attach_many(
        "test-oauth-authz-url-#{inspect(ref)}",
        [
          [:atex, :oauth, :authorization_url, :start],
          [:atex, :oauth, :authorization_url, :stop]
        ],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-oauth-authz-url-#{inspect(ref)}") end)

      authz_metadata = %{
        issuer: "https://bsky.social",
        par_endpoint: "https://bsky.social/oauth/par",
        token_endpoint: "https://bsky.social/oauth/token",
        authorization_endpoint: "https://bsky.social/oauth/authorize",
        revocation_endpoint: "https://bsky.social/oauth/revoke"
      }

      # This will fail (no real PAR server) but telemetry still fires
      Flow.create_authorization_url(authz_metadata, "state", "verifier", "user.bsky.social",
        key: key,
        client_id: "https://example.com/client",
        redirect_uri: "https://example.com/callback",
        scopes: "atproto"
      )

      assert_receive {:telemetry, [:atex, :oauth, :authorization_url, :start], %{system_time: _},
                      %{issuer: "https://bsky.social"}}

      assert_receive {:telemetry, [:atex, :oauth, :authorization_url, :stop], %{duration: _},
                      %{issuer: "https://bsky.social"}}
    end

    test "revoke_tokens/2 emits token_revocation start/stop events" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-oauth-revoke-#{inspect(ref)}",
        [
          [:atex, :oauth, :token_revocation, :start],
          [:atex, :oauth, :token_revocation, :stop]
        ],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-oauth-revoke-#{inspect(ref)}") end)

      session = %Atex.OAuth.Session{
        iss: "https://bsky.social",
        aud: "https://bsky.social",
        sub: "did:plc:abc",
        nonce: "nonce",
        access_token: "token",
        refresh_token: "refresh",
        expires_at: NaiveDateTime.utc_now(),
        dpop_key: JOSE.JWK.generate_key({:ec, "P-256"}),
        dpop_nonce: nil
      }

      authz_metadata = %{
        issuer: "https://bsky.social",
        par_endpoint: "https://bsky.social/oauth/par",
        token_endpoint: "https://bsky.social/oauth/token",
        authorization_endpoint: "https://bsky.social/oauth/authorize",
        revocation_endpoint: "https://bsky.social/oauth/revoke"
      }

      # Will fail (no real server) but telemetry fires
      Flow.revoke_tokens(session, authz_metadata)

      assert_receive {:telemetry, [:atex, :oauth, :token_revocation, :start], %{system_time: _},
                      %{issuer: "https://bsky.social"}}

      assert_receive {:telemetry, [:atex, :oauth, :token_revocation, :stop], %{duration: _},
                      %{issuer: "https://bsky.social"}}
    end
  end
end
