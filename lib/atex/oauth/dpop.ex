defmodule Atex.OAuth.DPoP do
  @moduledoc """
  DPoP (Demonstrating Proof of Possession) token creation and request handling.

  Provides functions to create DPoP proof JWTs and send DPoP-protected HTTP
  requests, handling the nonce retry dance required by the AT Protocol OAuth
  specification.
  """

  @doc """
  Create a DPoP proof token for a given request.

  Builds a signed JWT containing the HTTP method, URL (without query string),
  a random `jti`, the current timestamp, and an optional server nonce. Extra
  claims (e.g., `iss`, `ath`) can be merged in via `attrs`.

  ## Parameters

  - `jwk` - Private JWK used to sign the proof
  - `request` - The `Req.Request` the token is being produced for
  - `nonce` - Server-provided nonce (optional; omitted from JWT when `nil`)
  - `attrs` - Extra claims to merge into the JWT payload (default: `%{}`)
  """
  @spec create_dpop_token(JOSE.JWK.t(), Req.Request.t(), String.t() | nil, map()) :: String.t()
  def create_dpop_token(jwk, request, nonce \\ nil, attrs \\ %{}) do
    iat = System.os_time(:second)
    jti = random_b64(20)
    {_, public_jwk} = JOSE.JWK.to_public_map(jwk)
    jws = %{"alg" => "ES256", "typ" => "dpop+jwt", "jwk" => public_jwk}
    [request_url | _] = request.url |> to_string() |> String.split("?")

    jwt =
      Map.merge(attrs, %{
        jti: jti,
        htm: request.method |> to_string() |> String.upcase(),
        htu: request_url,
        iat: iat
      })
      |> then(fn m -> if nonce, do: Map.put(m, :nonce, nonce), else: m end)

    JOSE.JWT.sign(jwk, jws, jwt)
    |> JOSE.JWS.compact()
    |> elem(1)
  end

  @doc """
  Send a DPoP-protected request to a token endpoint.

  Attaches a DPoP proof to `request` and sends it. If the server responds with
  `use_dpop_nonce`, retries once with the returned nonce.

  ## Parameters

  - `request` - A `Req.Request` already configured with URL, method, and body
  - `dpop_key` - Private JWK for signing the DPoP proof
  - `nonce` - Current DPoP nonce, if any (default: `nil`)
  """
  @spec send_oauth_dpop_request(Req.Request.t(), JOSE.JWK.t(), String.t() | nil) ::
          {:ok, map(), String.t() | nil} | {:error, any(), String.t() | nil}
  def send_oauth_dpop_request(request, dpop_key, nonce \\ nil) do
    dpop_token = create_dpop_token(dpop_key, request, nonce)

    request
    |> Req.Request.put_header("dpop", dpop_token)
    |> Req.request()
    |> case do
      {:ok, %{status: 200, body: body} = resp} ->
        {:ok, body, extract_nonce(resp, nonce)}

      {:ok, %{body: %{"error" => "use_dpop_nonce"}} = resp} ->
        retry_token_request(request, dpop_key, extract_nonce(resp, nonce))

      {:ok, %{body: %{"error" => error, "error_description" => description}} = resp} ->
        {:error, {:oauth_error, error, description}, extract_nonce(resp, nonce)}

      {:ok, resp} ->
        {:error, :unexpected_response, extract_nonce(resp, nonce)}

      {:error, err} ->
        {:error, err, nonce}
    end
  end

  @doc """
  Send a DPoP-protected request to a resource server (e.g., a PDS endpoint).

  Attaches both the `Authorization: DPoP <token>` header (assumed already set on
  `request`) and a fresh DPoP proof. If the server returns a 401 with a
  `WWW-Authenticate: DPoP ...` header, retries once with the returned nonce.

  ## Parameters

  - `request` - A `Req.Request` with the Authorization header already set
  - `issuer` - Authorization server issuer URL (used in the `iss` claim)
  - `access_token` - The access token (used to compute the `ath` hash claim)
  - `dpop_key` - Private JWK for signing the DPoP proof
  - `nonce` - Current DPoP nonce, if any (default: `nil`)
  """
  @spec request_protected_dpop_resource(
          Req.Request.t(),
          String.t(),
          String.t(),
          JOSE.JWK.t(),
          String.t() | nil
        ) :: {:ok, Req.Response.t(), String.t() | nil} | {:error, any()}
  def request_protected_dpop_resource(request, issuer, access_token, dpop_key, nonce \\ nil) do
    access_token_hash = :crypto.hash(:sha256, access_token) |> Base.url_encode64(padding: false)
    extra_claims = %{iss: issuer, ath: access_token_hash}
    dpop_token = create_dpop_token(dpop_key, request, nonce, extra_claims)

    request
    |> Req.Request.put_header("dpop", dpop_token)
    |> Req.request()
    |> case do
      {:ok, %{status: 401} = resp} ->
        dpop_nonce = extract_nonce(resp, nonce)

        case Req.Response.get_header(resp, "www-authenticate") do
          ["DPoP" <> _ | _] -> retry_resource_request(request, dpop_key, dpop_nonce, extra_claims)
          _ -> {:ok, resp, dpop_nonce}
        end

      {:ok, resp} ->
        {:ok, resp, extract_nonce(resp, nonce)}

      {:error, _} = err ->
        err
    end
  end

  @spec retry_token_request(Req.Request.t(), JOSE.JWK.t(), String.t() | nil) ::
          {:ok, map(), String.t() | nil} | {:error, any(), String.t() | nil}
  defp retry_token_request(request, dpop_key, nonce) do
    dpop_token = create_dpop_token(dpop_key, request, nonce)

    request
    |> Req.Request.put_header("dpop", dpop_token)
    |> Req.request()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body, nonce}

      {:ok, %{body: %{"error" => error, "error_description" => description}}} ->
        {:error, {:oauth_error, error, description}, nonce}

      {:ok, _} ->
        {:error, :unexpected_response, nonce}

      {:error, err} ->
        {:error, err, nonce}
    end
  end

  @spec retry_resource_request(Req.Request.t(), JOSE.JWK.t(), String.t() | nil, map()) ::
          {:ok, Req.Response.t(), String.t() | nil} | {:error, any()}
  defp retry_resource_request(request, dpop_key, nonce, extra_claims) do
    dpop_token = create_dpop_token(dpop_key, request, nonce, extra_claims)

    request
    |> Req.Request.put_header("dpop", dpop_token)
    |> Req.request()
    |> case do
      {:ok, resp} ->
        dpop_nonce = extract_nonce(resp, nonce)
        {:ok, resp, dpop_nonce}

      {:error, _} = err ->
        err
    end
  end

  @spec extract_nonce(Req.Response.t(), String.t() | nil) :: String.t() | nil
  defp extract_nonce(resp, fallback) do
    case resp.headers["dpop-nonce"] do
      [new_nonce | _] -> new_nonce
      _ -> fallback
    end
  end

  @spec random_b64(integer()) :: String.t()
  defp random_b64(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64(padding: false)
  end
end
