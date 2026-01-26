defmodule Atex.OAuth do
  @moduledoc """
  OAuth 2.0 implementation for AT Protocol authentication.

  This module provides utilities for implementing OAuth flows compliant with the
  AT Protocol specification. It includes support for:

  - Pushed Authorization Requests (PAR)
  - DPoP (Demonstration of Proof of Possession) tokens
  - JWT client assertions
  - PKCE (Proof Key for Code Exchange)
  - Token refresh
  - Handle to PDS resolution

  ## Configuration

  See `Atex.Config.OAuth` module for configuration documentation.

  ## Usage Example

      iex> pds = "https://bsky.social"
      iex> login_hint = "example.com"
      iex> {:ok, authz_server} = Atex.OAuth.get_authorization_server(pds)
      iex> {:ok, authz_metadata} = Atex.OAuth.get_authorization_server_metadata(authz_server)
      iex> state = Atex.OAuth.create_nonce()
      iex> code_verifier = Atex.OAuth.create_nonce()
      iex> {:ok, auth_url} = Atex.OAuth.create_authorization_url(
        authz_metadata,
        state,
        code_verifier,
        login_hint
      )
  """

  @type authorization_metadata() :: %{
          issuer: String.t(),
          par_endpoint: String.t(),
          token_endpoint: String.t(),
          authorization_endpoint: String.t()
        }

  @type tokens() :: %{
          access_token: String.t(),
          refresh_token: String.t(),
          did: String.t(),
          expires_at: NaiveDateTime.t()
        }

  alias Atex.Config.OAuth, as: Config

  @doc """
  Get a map cnotaining the client metadata information needed for an
  authorization server to validate this client.
  """
  @type create_client_metadata_option ::
          {:key, JOSE.JWK.t()}
          | {:client_id, String.t()}
          | {:redirect_uri, String.t()}
          | {:extra_redirect_uris, list(String.t())}
          | {:scopes, String.t()}
  @spec create_client_metadata(list(create_client_metadata_option())) :: map()
  def create_client_metadata(opts \\ []) do
    opts =
      Keyword.validate!(opts,
        key: Config.get_key(),
        client_id: Config.client_id(),
        redirect_uri: Config.redirect_uri(),
        extra_redirect_uris: Config.extra_redirect_uris(),
        scopes: Config.scopes()
      )

    key = Keyword.get(opts, :key)
    client_id = Keyword.get(opts, :client_id)
    redirect_uri = Keyword.get(opts, :redirect_uri)
    extra_redirect_uris = Keyword.get(opts, :extra_redirect_uris)
    scopes = Keyword.get(opts, :scopes)

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
  Retrieves the configured JWT private key for signing client assertions.

  Loads the private key from configuration, decodes the base64-encoded DER data,
  and creates a JOSE JWK structure with the key ID field set.

  ## Returns

  A `JOSE.JWK` struct containing the private key and key identifier.

  ## Raises

  * `Application.Env.Error` if the private_key or key_id configuration is missing

  ## Examples

      key = OAuth.get_key()
      key = OAuth.get_key()
  """
  @spec get_key() :: JOSE.JWK.t()
  def get_key(), do: Config.get_key()

  @doc false
  @spec random_b64(integer()) :: String.t()
  def random_b64(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64(padding: false)
  end

  @doc false
  @spec create_nonce() :: String.t()
  def create_nonce(), do: random_b64(32)

  @doc """
  Create an OAuth authorization URL for a PDS.

  Submits a PAR request to the authorization server and constructs the
  authorization URL with the returned request URI. Supports PKCE, DPoP, and
  client assertions as required by the AT Protocol.

  ## Parameters

    - `authz_metadata` - Authorization server metadata containing endpoints, fetched from `get_authorization_server_metadata/1`
    - `state` - Random token for session validation
    - `code_verifier` - PKCE code verifier
    - `login_hint` - User identifier (handle or DID) for pre-filled login

  ## Returns

    - `{:ok, authorization_url}` - Successfully created authorization URL
    - `{:ok, :invalid_par_response}` - Server respondend incorrectly to the request
    - `{:error, reason}` - Error creating authorization URL
  """
  @type create_authorization_url_option ::
          {:key, JOSE.JWK.t()}
          | {:client_id, String.t()}
          | {:redirect_uri, String.t()}
          | {:scopes, String.t()}
  @spec create_authorization_url(
          authorization_metadata(),
          String.t(),
          String.t(),
          String.t(),
          list(create_authorization_url_option())
        ) :: {:ok, String.t()} | {:error, any()}
  def create_authorization_url(
        authz_metadata,
        state,
        code_verifier,
        login_hint,
        opts \\ []
      ) do
    opts =
      Keyword.validate!(opts,
        key: Config.get_key(),
        client_id: Config.client_id(),
        redirect_uri: Config.redirect_uri(),
        scopes: Config.scopes()
      )

    key = Keyword.get(opts, :key)
    client_id = Keyword.get(opts, :client_id)
    redirect_uri = Keyword.get(opts, :redirect_uri)
    scopes = Keyword.get(opts, :scopes)

    code_challenge = :crypto.hash(:sha256, code_verifier) |> Base.url_encode64(padding: false)

    client_assertion =
      create_client_assertion(key, client_id, authz_metadata.issuer)

    body =
      %{
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
        query =
          %{client_id: client_id, request_uri: request_uri}
          |> URI.encode_query()

        {:ok, "#{authz_metadata.authorization_endpoint}?#{query}"}

      {:ok, _} ->
        {:error, :invalid_par_response}

      err ->
        err
    end
  end

  @doc """
  Exchange an OAuth authorization code for a set of access and refresh tokens.

  Validates the authorization code by submitting it to the token endpoint along with
  the PKCE code verifier and client assertion. Returns access tokens for making authenticated
  requests to the relevant user's PDS.

  ## Parameters

    - `authz_metadata` - Authorization server metadata containing token endpoint
    - `dpop_key` - JWK for DPoP token generation
    - `code` - Authorization code from OAuth callback
    - `code_verifier` - PKCE code verifier from authorization flow

  ## Returns

    - `{:ok, tokens, nonce}` - Successfully obtained tokens with returned DPoP nonce
    - `{:error, reason}` - Error exchanging code for tokens
  """
  @type validate_authorization_code_option ::
          {:key, JOSE.JWK.t()}
          | {:client_id, String.t()}
          | {:redirect_uri, String.t()}
          | {:scopes, String.t()}
  @spec validate_authorization_code(
          authorization_metadata(),
          JOSE.JWK.t(),
          String.t(),
          String.t(),
          list(validate_authorization_code_option())
        ) :: {:ok, tokens(), String.t()} | {:error, any()}
  def validate_authorization_code(
        authz_metadata,
        dpop_key,
        code,
        code_verifier,
        opts \\ []
      ) do
    opts =
      Keyword.validate!(opts,
        key: get_key(),
        client_id: Config.client_id(),
        redirect_uri: Config.redirect_uri(),
        scopes: Config.scopes()
      )

    key = Keyword.get(opts, :key)
    client_id = Keyword.get(opts, :client_id)
    redirect_uri = Keyword.get(opts, :redirect_uri)

    client_assertion =
      create_client_assertion(key, client_id, authz_metadata.issuer)

    body =
      %{
        grant_type: "authorization_code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        code: code,
        code_verifier: code_verifier,
        client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        client_assertion: client_assertion
      }

    Req.new(method: :post, url: authz_metadata.token_endpoint, form: body)
    |> send_oauth_dpop_request(dpop_key)
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

      err ->
        err
    end
  end

  @type refresh_token_option ::
          {:key, JOSE.JWK.t()}
          | {:client_id, String.t()}
          | {:redirect_uri, String.t()}
          | {:scopes, String.t()}
  @spec refresh_token(
          String.t(),
          JOSE.JWK.t(),
          String.t(),
          String.t(),
          list(refresh_token_option())
        ) ::
          {:ok, tokens(), String.t()} | {:error, any()}
  def refresh_token(refresh_token, dpop_key, issuer, token_endpoint, opts \\ []) do
    opts =
      Keyword.validate!(opts,
        key: get_key(),
        client_id: Config.client_id(),
        redirect_uri: Config.redirect_uri(),
        scopes: Config.scopes()
      )

    key = Keyword.get(opts, :key)
    client_id = Keyword.get(opts, :client_id)

    client_assertion =
      create_client_assertion(key, client_id, issuer)

    body = %{
      grant_type: "refresh_token",
      refresh_token: refresh_token,
      client_id: client_id,
      client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      client_assertion: client_assertion
    }

    Req.new(method: :post, url: token_endpoint, form: body)
    |> send_oauth_dpop_request(dpop_key)
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

      err ->
        err
    end
  end

  @doc """
  Fetch the authorization server for a given Personal Data Server (PDS).

  Makes a request to the PDS's `.well-known/oauth-protected-resource` endpoint
  to discover the associated authorization server that should be used for the
  OAuth flow. Results are cached for 1 hour to reduce load on third-party PDSs.

  ## Parameters

    - `pds_host` - Base URL of the PDS (e.g., "https://bsky.social")
    - `fresh` - If `true`, bypasses the cache and fetches fresh data (default: `false`)

  ## Returns

    - `{:ok, authorization_server}` - Successfully discovered authorization
      server URL
    - `{:error, :invalid_metadata}` - Server returned invalid metadata
    - `{:error, reason}` - Error discovering authorization server
  """
  @spec get_authorization_server(String.t(), boolean()) :: {:ok, String.t()} | {:error, any()}
  def get_authorization_server(pds_host, fresh \\ false) do
    if fresh do
      fetch_authorization_server(pds_host)
    else
      case Atex.OAuth.Cache.get_authorization_server(pds_host) do
        {:ok, authz_server} ->
          {:ok, authz_server}

        {:error, :not_found} ->
          fetch_authorization_server(pds_host)
      end
    end
  end

  defp fetch_authorization_server(pds_host) do
    result =
      "#{pds_host}/.well-known/oauth-protected-resource"
      |> Req.get()
      |> case do
        # TODO: what to do when multiple authorization servers?
        {:ok, %{body: %{"authorization_servers" => [authz_server | _]}}} -> {:ok, authz_server}
        {:ok, _} -> {:error, :invalid_metadata}
        err -> err
      end

    case result do
      {:ok, authz_server} ->
        Atex.OAuth.Cache.set_authorization_server(pds_host, authz_server)
        {:ok, authz_server}

      error ->
        error
    end
  end

  @doc """
  Fetch the metadata for an OAuth authorization server.

  Retrieves the metadata from the authorization server's
  `.well-known/oauth-authorization-server` endpoint, providing endpoint URLs
  required for the OAuth flow. Results are cached for 1 hour to reduce load on
  third-party PDSs.

  ## Parameters

    - `issuer` - Authorization server issuer URL
    - `fresh` - If `true`, bypasses the cache and fetches fresh data (default: `false`)

  ## Returns

    - `{:ok, metadata}` - Successfully retrieved authorization server metadata
    - `{:error, :invalid_metadata}` - Server returned invalid metadata
    - `{:error, :invalid_issuer}` - Issuer mismatch in metadata
    - `{:error, any()}` - Other error fetching metadata
  """
  @spec get_authorization_server_metadata(String.t(), boolean()) ::
          {:ok, authorization_metadata()} | {:error, any()}
  def get_authorization_server_metadata(issuer, fresh \\ false) do
    if fresh do
      fetch_authorization_server_metadata(issuer)
    else
      case Atex.OAuth.Cache.get_authorization_server_metadata(issuer) do
        {:ok, metadata} ->
          {:ok, metadata}

        {:error, :not_found} ->
          fetch_authorization_server_metadata(issuer)
      end
    end
  end

  defp fetch_authorization_server_metadata(issuer) do
    result =
      "#{issuer}/.well-known/oauth-authorization-server"
      |> Req.get()
      |> case do
        {:ok,
         %{
           body: %{
             "issuer" => metadata_issuer,
             "pushed_authorization_request_endpoint" => par_endpoint,
             "token_endpoint" => token_endpoint,
             "authorization_endpoint" => authorization_endpoint
           }
         }} ->
          if issuer != metadata_issuer do
            {:error, :invaild_issuer}
          else
            {:ok,
             %{
               issuer: metadata_issuer,
               par_endpoint: par_endpoint,
               token_endpoint: token_endpoint,
               authorization_endpoint: authorization_endpoint
             }}
          end

        {:ok, _} ->
          {:error, :invalid_metadata}

        err ->
          err
      end

    case result do
      {:ok, metadata} ->
        Atex.OAuth.Cache.set_authorization_server_metadata(issuer, metadata)
        {:ok, metadata}

      error ->
        error
    end
  end

  @spec send_oauth_dpop_request(Req.Request.t(), JOSE.JWK.t(), String.t() | nil) ::
          {:ok, map(), String.t()} | {:error, any(), String.t()}
  def send_oauth_dpop_request(request, dpop_key, nonce \\ nil) do
    dpop_token = create_dpop_token(dpop_key, request, nonce)

    request
    |> Req.Request.put_header("dpop", dpop_token)
    |> Req.request()
    |> case do
      {:ok, resp} ->
        dpop_nonce =
          case resp.headers["dpop-nonce"] do
            [new_nonce | _] -> new_nonce
            _ -> nonce
          end

        cond do
          resp.status == 200 ->
            {:ok, resp.body, dpop_nonce}

          resp.body["error"] === "use_dpop_nonce" ->
            dpop_token = create_dpop_token(dpop_key, request, dpop_nonce)

            request
            |> Req.Request.put_header("dpop", dpop_token)
            |> Req.request()
            |> case do
              {:ok, %{status: 200, body: body}} ->
                {:ok, body, dpop_nonce}

              {:ok, %{body: %{"error" => error, "error_description" => error_description}}} ->
                {:error, {:oauth_error, error, error_description}, dpop_nonce}

              {:ok, _} ->
                {:error, :unexpected_response, dpop_nonce}

              {:error, err} ->
                {:error, err, dpop_nonce}
            end

          true ->
            {:error, {:oauth_error, resp.body["error"], resp.body["error_description"]},
             dpop_nonce}
        end

      {:error, err} ->
        {:error, err, nonce}
    end
  end

  @spec request_protected_dpop_resource(
          Req.Request.t(),
          String.t(),
          String.t(),
          JOSE.JWK.t(),
          String.t() | nil
        ) :: {:ok, Req.Response.t(), String.t() | nil} | {:error, any()}
  def request_protected_dpop_resource(request, issuer, access_token, dpop_key, nonce \\ nil) do
    access_token_hash = :crypto.hash(:sha256, access_token) |> Base.url_encode64(padding: false)
    # access_token_hash = Base.url_encode64(access_token, padding: false)

    dpop_token =
      create_dpop_token(dpop_key, request, nonce, %{iss: issuer, ath: access_token_hash})

    request
    |> Req.Request.put_header("dpop", dpop_token)
    |> Req.request()
    |> case do
      {:ok, resp} ->
        dpop_nonce =
          case resp.headers["dpop-nonce"] do
            [new_nonce | _] -> new_nonce
            _ -> nonce
          end

        www_authenticate = Req.Response.get_header(resp, "www-authenticate")

        www_dpop_problem =
          www_authenticate != [] && String.starts_with?(Enum.at(www_authenticate, 0), "DPoP")

        if resp.status != 401 || !www_dpop_problem do
          {:ok, resp, dpop_nonce}
        else
          dpop_token =
            create_dpop_token(dpop_key, request, dpop_nonce, %{
              iss: issuer,
              ath: access_token_hash
            })

          request
          |> Req.Request.put_header("dpop", dpop_token)
          |> Req.request()
          |> case do
            {:ok, resp} ->
              dpop_nonce =
                case resp.headers["dpop-nonce"] do
                  [new_nonce | _] -> new_nonce
                  _ -> dpop_nonce
                end

              {:ok, resp, dpop_nonce}

            err ->
              err
          end
        end

      err ->
        err
    end
  end

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

  @spec create_dpop_token(JOSE.JWK.t(), Req.Request.t(), any(), map()) :: String.t()
  def create_dpop_token(jwk, request, nonce \\ nil, attrs \\ %{}) do
    iat = System.os_time(:second)
    jti = random_b64(20)
    {_, public_jwk} = JOSE.JWK.to_public_map(jwk)
    jws = %{"alg" => "ES256", "typ" => "dpop+jwt", "jwk" => public_jwk}
    [request_url | _] = request.url |> to_string() |> String.split("?")

    jwt =
      Map.merge(attrs, %{
        jti: jti,
        htm: atom_to_upcase_string(request.method),
        htu: request_url,
        iat: iat
      })
      |> then(fn m ->
        if nonce, do: Map.put(m, :nonce, nonce), else: m
      end)

    JOSE.JWT.sign(jwk, jws, jwt)
    |> JOSE.JWS.compact()
    |> elem(1)
  end

  @doc false
  @spec atom_to_upcase_string(atom()) :: String.t()
  def atom_to_upcase_string(atom) do
    atom |> to_string() |> String.upcase()
  end
end
