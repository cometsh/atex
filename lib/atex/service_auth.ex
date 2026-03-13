defmodule Atex.ServiceAuth do
  @moduledoc """
  Validating and working with inter-service authentication tokens.

  Provides functions for validating [ATProto inter-service authentication JWTs](https://atproto.com/specs/xrpc#inter-service-authentication-jwt),
  either from a raw token string or directly from an incoming `Plug.Conn`.

  Validation covers:

  - Token timing (`iat` not in the future, `exp` not in the past).
  - Audience (`aud`) matching the caller-supplied expected value.
  - Optional lexicon method (`lxm`) matching the caller-supplied expected value.
  - Issuer DID resolution and signing-key verification via `Atex.IdentityResolver`.
  - Replay prevention via `Atex.ServiceAuth.JTICache` - each `jti` nonce may
    only be accepted once.

  ## Configuration

  The JTI cache implementation is pluggable. See `Atex.ServiceAuth.JTICache` for
  details.
  """

  import Plug.Conn

  @typedoc """
  Options accepted by `validate_conn/2` and `validate_jwt/2`.

  - `:aud` - **required**. The expected audience string. The token's `aud` claim
    must equal this value exactly.
  - `:lxm` - optional. When provided, the token's `lxm` claim must match. If
    the token omits `lxm` the check is skipped; if the token carries `lxm` but
    no expected value is configured, validation fails with `:lxm_not_configured`.
  """
  @type validate_option() :: {:lxm, String.t()} | {:aud, String.t()}

  @doc """
  Validate a service auth token from a `Plug.Conn` request.

  Extracts the `Authorization: Bearer <jwt>` header and delegates to
  `validate_jwt/2`. Returns `{:error, :missing_token}` when the header is
  absent or malformed.

  ## Options

  See `t:validate_option/0`.

  ## Examples

      iex> Atex.ServiceAuth.validate_conn(conn, aud: "did:web:my-service.example")
      {:ok, %JOSE.JWT{}}

      iex> Atex.ServiceAuth.validate_conn(conn, aud: "did:web:my-service.example", lxm: "app.bsky.feed.getTimeline")
      {:error, :lxm_mismatch}
  """
  @spec validate_conn(Plug.Conn.t(), list(validate_option())) ::
          {:ok, jwt :: JOSE.JWT.t()} | {:error, reason :: atom()}
  def validate_conn(conn, opts \\ []) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> jwt] -> validate_jwt(jwt, opts)
      [_] -> :error
      _ -> :error
    end
  end

  @doc """
  Validate a raw service auth JWT string.

  Performs the full validation pipeline:

  1. Decodes the JWT payload (without verifying the signature yet) to extract claims.
  2. Validates `:aud` and `:lxm` against the provided options.
  3. Validates token timing (`iat`, `exp`).
  4. Resolves the issuer DID and retrieves the ATProto signing key from their
     DID document.
  5. Verifies the JWT signature with the resolved key.
  6. Records the `jti` nonce in `Atex.ServiceAuth.JTICache` - returns
     `{:error, :replayed_token}` if it has already been seen.

  ## Options

  See `t:validate_option/0`.

  ## Error reasons

  - `:aud_mismatch` - `aud` claim does not match the expected audience.
  - `:lxm_mismatch` - `lxm` claim does not match the expected lexicon method.
  - `:lxm_not_configured` - token carries an `lxm` claim but no expected value
    was provided via `:lxm` opt.
  - `:future_iat` - `iat` is in the future.
  - `:expired` - `exp` is in the past.
  - `:replayed_token` - `jti` has already been used.

  ## Examples

      iex> Atex.ServiceAuth.validate_jwt(jwt, aud: "did:web:my-service.example")
      {:ok, %JOSE.JWT{}}

      iex> Atex.ServiceAuth.validate_jwt(expired_jwt, aud: "did:web:my-service.example")
      {:error, :expired}
  """
  @spec validate_jwt(String.t(), list(validate_option())) ::
          {:ok, jwt :: JOSE.JWT.t()} | {:error, reason :: atom()}
  def validate_jwt(jwt, opts \\ []) do
    {expected_aud, expected_lxm} = options(opts)

    %{
      fields:
        %{
          "aud" => target_aud,
          "iat" => iat,
          "exp" => exp,
          "iss" => issuing_did,
          "jti" => nonce
        } = fields
    } = JOSE.JWT.peek(jwt)

    target_lxm = Map.get(fields, "lxm")

    with :ok <- validate_aud(expected_aud, target_aud),
         :ok <- validate_lxm(expected_lxm, target_lxm),
         :ok <- validate_token_times(iat, exp),
         # Resolve JWT's issuer to: a) make sure it's a real identity, b) get
         # the signing key from their DID document to verify the token
         {:ok, identity} <- Atex.IdentityResolver.resolve(issuing_did),
         user_jwk when not is_nil(user_jwk) <-
           Atex.DID.Document.get_atproto_signing_key(identity.document),
         {true, %JOSE.JWT{} = jwt_struct, _jws} <- JOSE.JWT.verify(user_jwk, jwt),
         # Record the nonce atomically after successful verification. insert_new
         # is used under the hood so this returns :seen if the jti was already
         # consumed, preventing replay attacks.
         :ok <- Atex.ServiceAuth.JTICache.put(nonce, exp) do
      {:ok, jwt_struct}
    else
      :seen -> {:error, :replayed_token}
      err -> err
    end
  end

  @spec validate_token_times(integer(), integer()) :: :ok | {:error, reason :: atom()}
  defp validate_token_times(iat, exp) do
    now = DateTime.utc_now()

    with {:ok, iat} <- DateTime.from_unix(iat),
         {:ok, exp} <- DateTime.from_unix(exp) do
      cond do
        DateTime.before?(now, iat) ->
          {:error, :future_iat}

        DateTime.after?(now, exp) ->
          {:error, :expired}

        true ->
          :ok
      end
    end
  end

  @spec validate_aud(String.t(), String.t()) :: :ok | {:error, reason :: atom()}
  defp validate_aud(expected, target) when expected == target, do: :ok
  defp validate_aud(_expected, _target), do: {:error, :aud_mismatch}

  @spec validate_lxm(String.t() | nil, String.t() | nil) :: :ok | {:error, reason :: atom()}
  defp validate_lxm(expected, target) when expected == target, do: :ok
  # `lxm` in JWTs is currently optional so we can do this.
  # TODO: should have an option to force requirement (e.g. for security-sensitive operations)
  defp validate_lxm(expected, nil) when is_binary(expected), do: :ok
  defp validate_lxm(nil, target) when is_binary(target), do: {:error, :lxm_not_configured}
  defp validate_lxm(expected, target) when expected != target, do: {:error, :lxm_mismatch}

  @spec options(list(validate_option())) :: {aud :: String.t(), lxm :: String.t() | nil}
  defp options(opts) do
    opts = Keyword.validate!(opts, aud: nil, lxm: nil)
    aud = Keyword.get(opts, :aud)
    lxm = Keyword.get(opts, :lxm)

    if !aud do
      raise ArgumentError, "`:aud` option is required for service auth validation"
    end

    {aud, lxm}
  end
end
