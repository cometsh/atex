defmodule Atex.OAuth.Flow do
  @moduledoc """
  AT Protocol OAuth 2.0 authorization flow.

  Handles the full OAuth protocol interactions: pushed authorization requests
  (PAR), authorization code exchange, token refresh, token revocation, client
  metadata, and client assertions.

  See `Atex.OAuth.Discovery` for authorization server discovery and
  `Atex.OAuth.DPoP` for DPoP token creation.
  """

  require Logger

  alias Atex.Config.OAuth, as: Config
  alias Atex.OAuth.{DPoP, Session}

  @type authorization_metadata() :: %{
          issuer: String.t(),
          par_endpoint: String.t(),
          token_endpoint: String.t(),
          authorization_endpoint: String.t(),
          revocation_endpoint: String.t()
        }

  @type tokens() :: %{
          access_token: String.t(),
          refresh_token: String.t(),
          did: String.t(),
          expires_at: NaiveDateTime.t()
        }

  @type create_client_metadata_option ::
          {:key, JOSE.JWK.t()}
          | {:client_id, String.t()}
          | {:redirect_uri, String.t()}
          | {:extra_redirect_uris, list(String.t())}
          | {:scopes, String.t()}

  @type create_authorization_url_option ::
          {:key, JOSE.JWK.t()}
          | {:client_id, String.t()}
          | {:redirect_uri, String.t()}
          | {:scopes, String.t()}

  @type validate_authorization_code_option ::
          {:key, JOSE.JWK.t()}
          | {:client_id, String.t()}
          | {:redirect_uri, String.t()}
          | {:scopes, String.t()}

  @type refresh_token_option ::
          {:key, JOSE.JWK.t()}
          | {:client_id, String.t()}

  @doc """
  Get a map containing the client metadata information needed for an
  authorization server to validate this client.
  """
  @spec create_client_metadata(list(create_client_metadata_option())) :: map()
  def create_client_metadata(opts \\ []) do
    opts =
      Keyword.validate!(opts, [:key, :client_id, :redirect_uri, :extra_redirect_uris, :scopes])

    key = Keyword.get_lazy(opts, :key, &Config.get_key/0)
    client_id = Keyword.get_lazy(opts, :client_id, &Config.client_id/0)
    redirect_uri = Keyword.get_lazy(opts, :redirect_uri, &Config.redirect_uri/0)

    extra_redirect_uris =
      Keyword.get_lazy(opts, :extra_redirect_uris, &Config.extra_redirect_uris/0)

    scopes = Keyword.get_lazy(opts, :scopes, &Config.scopes/0)

    {_, jwk} = key |> JOSE.JWK.to_public_map()
    jwk = Map.merge(jwk, %{use: "sig", kid: key.fields["kid"]})

    %{
      client_id: client_id,
      redirect_uris: [redirect_uri | extra_redirect_uris],
      application_type: "web",
      grant_types: ["authorization_code", "refresh_token"],
      scope: scopes,
      response_type: ["code"],
      token_endpoint_auth_method: "private_key_jwt",
      token_endpoint_auth_signing_alg: "ES256",
      dpop_bound_access_tokens: true,
      jwks: %{keys: [jwk]}
    }
  end

  @doc """
  Create a JWT client assertion for authenticating with an authorization server.

  Signs a short-lived (60 second) JWT with the client's private key, identifying
  the client to the authorization server.

  ## Parameters

  - `jwk` - Client private key (must have a `kid` field set)
  - `client_id` - OAuth client identifier
  - `issuer` - Authorization server issuer URL (used as `aud`)
  """
  @spec create_client_assertion(JOSE.JWK.t(), String.t(), String.t()) :: String.t()
  def create_client_assertion(jwk, client_id, issuer) do
    iat = System.os_time(:second)
    jti = random_b64(20)
    jws = %{"alg" => "ES256", "kid" => jwk.fields["kid"]}

    jwt = %{
      iss: client_id,
      sub: client_id,
      aud: issuer,
      jti: jti,
      iat: iat,
      exp: iat + 60
    }

    JOSE.JWT.sign(jwk, jws, jwt)
    |> JOSE.JWS.compact()
    |> elem(1)
  end

  @doc """
  Create an OAuth authorization URL for a PDS.

  Submits a PAR request to the authorization server and constructs the
  authorization URL with the returned request URI. Supports PKCE, DPoP, and
  client assertions as required by the AT Protocol.

  ## Parameters

  - `authz_metadata` - Authorization server metadata, from `Atex.OAuth.Discovery.get_authorization_server_metadata/2`
  - `state` - Random token for session validation
  - `code_verifier` - PKCE code verifier
  - `login_hint` - User identifier (handle or DID) for pre-filled login
  - `opts` - Optional overrides for `:key`, `:client_id`, `:redirect_uri`, `:scopes`

  ## Returns

  - `{:ok, authorization_url}` - Successfully created authorization URL
  - `{:error, :invalid_par_response}` - Server responded incorrectly to the PAR request
  - `{:error, reason}` - Error creating authorization URL
  """
  @spec create_authorization_url(
          authorization_metadata(),
          String.t(),
          String.t(),
          String.t(),
          list(create_authorization_url_option())
        ) :: {:ok, String.t()} | {:error, any()}
  def create_authorization_url(authz_metadata, state, code_verifier, login_hint, opts \\ []) do
    opts = Keyword.validate!(opts, [:key, :client_id, :redirect_uri, :scopes])

    key = Keyword.get_lazy(opts, :key, &Config.get_key/0)
    client_id = Keyword.get_lazy(opts, :client_id, &Config.client_id/0)
    redirect_uri = Keyword.get_lazy(opts, :redirect_uri, &Config.redirect_uri/0)
    scopes = Keyword.get_lazy(opts, :scopes, &Config.scopes/0)

    code_challenge = :crypto.hash(:sha256, code_verifier) |> Base.url_encode64(padding: false)
    client_assertion = create_client_assertion(key, client_id, authz_metadata.issuer)

    body = %{
      response_type: "code",
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
      code_challenge_method: "S256",
      code_challenge: code_challenge,
      scope: scopes,
      client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      client_assertion: client_assertion,
      login_hint: login_hint
    }

    case Req.post(authz_metadata.par_endpoint, form: body) do
      {:ok, %{body: %{"request_uri" => request_uri}}} ->
        query = %{client_id: client_id, request_uri: request_uri} |> URI.encode_query()
        {:ok, "#{authz_metadata.authorization_endpoint}?#{query}"}

      {:ok, _} ->
        {:error, :invalid_par_response}

      err ->
        err
    end
  end

  @doc """
  Exchange an OAuth authorization code for a set of access and refresh tokens.

  Validates the authorization code by submitting it to the token endpoint along
  with the PKCE code verifier and client assertion. Returns access tokens for
  making authenticated requests to the relevant user's PDS.

  ## Parameters

  - `authz_metadata` - Authorization server metadata containing token endpoint
  - `dpop_key` - JWK for DPoP token generation
  - `code` - Authorization code from OAuth callback
  - `code_verifier` - PKCE code verifier from authorization flow
  - `opts` - Optional overrides for `:key`, `:client_id`, `:redirect_uri`, `:scopes`

  ## Returns

  - `{:ok, tokens, nonce}` - Successfully obtained tokens with returned DPoP nonce
  - `{:error, reason}` - Error exchanging code for tokens
  """
  @spec validate_authorization_code(
          authorization_metadata(),
          JOSE.JWK.t(),
          String.t(),
          String.t(),
          list(validate_authorization_code_option())
        ) :: {:ok, tokens(), String.t() | nil} | {:error, any()}
  def validate_authorization_code(authz_metadata, dpop_key, code, code_verifier, opts \\ []) do
    opts = Keyword.validate!(opts, [:key, :client_id, :redirect_uri, :scopes])

    key = Keyword.get_lazy(opts, :key, &Config.get_key/0)
    client_id = Keyword.get_lazy(opts, :client_id, &Config.client_id/0)
    redirect_uri = Keyword.get_lazy(opts, :redirect_uri, &Config.redirect_uri/0)

    client_assertion = create_client_assertion(key, client_id, authz_metadata.issuer)

    body = %{
      grant_type: "authorization_code",
      client_id: client_id,
      redirect_uri: redirect_uri,
      code: code,
      code_verifier: code_verifier
    }

    body =
      if Config.localhost?(),
        do: body,
        else:
          Map.merge(body, %{
            client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
            client_assertion: client_assertion
          })

    Req.new(method: :post, url: authz_metadata.token_endpoint, form: body)
    |> DPoP.send_oauth_dpop_request(dpop_key)
    |> case do
      {:ok,
       %{
         "access_token" => access_token,
         "refresh_token" => refresh_token,
         "expires_in" => expires_in,
         "sub" => did
       }, nonce} ->
        expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(expires_in, :second)

        {:ok,
         %{
           access_token: access_token,
           refresh_token: refresh_token,
           did: did,
           expires_at: expires_at
         }, nonce}

      {:error, reason, _nonce} ->
        {:error, reason}
    end
  end

  @doc """
  Refresh an existing set of OAuth tokens.

  Submits the refresh token to the token endpoint using DPoP authentication and
  a client assertion. Returns the new token set with an updated DPoP nonce.

  ## Parameters

  - `refresh_token` - The refresh token to exchange
  - `dpop_key` - JWK for DPoP token generation
  - `issuer` - Authorization server issuer URL (for client assertion `aud`)
  - `token_endpoint` - Token endpoint URL
  - `opts` - Optional overrides for `:key`, `:client_id`
  """
  @spec refresh_token(
          String.t(),
          JOSE.JWK.t(),
          String.t(),
          String.t(),
          list(refresh_token_option())
        ) :: {:ok, tokens(), String.t() | nil} | {:error, any()}
  def refresh_token(refresh_token, dpop_key, issuer, token_endpoint, opts \\ []) do
    opts = Keyword.validate!(opts, [:key, :client_id])

    key = Keyword.get_lazy(opts, :key, &Config.get_key/0)
    client_id = Keyword.get_lazy(opts, :client_id, &Config.client_id/0)

    client_assertion = create_client_assertion(key, client_id, issuer)

    body = %{
      grant_type: "refresh_token",
      refresh_token: refresh_token,
      client_id: client_id,
      client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      client_assertion: client_assertion
    }

    Req.new(method: :post, url: token_endpoint, form: body)
    |> DPoP.send_oauth_dpop_request(dpop_key)
    |> case do
      {:ok,
       %{
         "access_token" => access_token,
         "refresh_token" => refresh_token,
         "expires_in" => expires_in,
         "sub" => did
       }, nonce} ->
        expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(expires_in, :second)

        {:ok,
         %{
           access_token: access_token,
           refresh_token: refresh_token,
           did: did,
           expires_at: expires_at
         }, nonce}

      {:error, reason, _nonce} ->
        {:error, reason}
    end
  end

  @doc """
  Revokes the access and refresh tokens with the authorization server.

  Sends the refresh token to the revocation endpoint as defined in RFC 7009.
  Token revocation failures are logged as warnings rather than returned as
  errors, since the primary goal (ending the session) is still achieved.

  ## Parameters

  - `session` - The session containing tokens to revoke
  - `authz_metadata` - Authorization server metadata including `revocation_endpoint`

  ## Returns

  - `:ok` - Tokens revoked (or revocation endpoint unreachable - logged, not raised)
  """
  @spec revoke_tokens(Session.t(), authorization_metadata()) :: :ok
  def revoke_tokens(%Session{} = session, authz_metadata) do
    client_id = Config.client_id()

    body = %{
      client_id: client_id,
      token: session.refresh_token,
      token_type_hint: "refresh_token"
    }

    case Req.post(authz_metadata.revocation_endpoint, form: body) do
      {:ok, %{status: status}} when status in [200, 204] ->
        :ok

      {:ok, %{body: %{"error" => error}}} ->
        Logger.warning("Token revocation failed: #{error}")
        :ok

      {:error, reason} ->
        Logger.warning("Token revocation request failed: #{inspect(reason)}")
        :ok

      unexpected ->
        Logger.warning("Unexpected token revocation response: #{inspect(unexpected)}")
        :ok
    end
  end

  @spec random_b64(integer()) :: String.t()
  defp random_b64(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64(padding: false)
  end
end
