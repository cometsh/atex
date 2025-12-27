defmodule Atex.OAuth.Plug do
  @moduledoc """
  Plug router for handling AT Protocol's OAuth flow.

  This module provides three endpoints:

  - `GET /login?handle=<handle>` - Initiates the OAuth authorization flow for a
    given handle
  - `GET /callback` - Handles the OAuth callback after user authorization
  - `GET /client-metadata.json` - Serves the OAuth client metadata

  ## Usage

  This module requires `Plug.Session` to be in your pipeline, as well as
  `secret_key_base` to have been set on your connections. Ideally it should be
  routed to via `Plug.Router.forward/2`, under a route like "/oauth".

  The plug requires a `:callback` option that must be an MFA tuple (Module,
  Function, Args). This callback is invoked after successful OAuth
  authentication, receiving the connection with the authenticated session data.

  ## Error Handling

  `Atex.OAuth.Error` exceptions are raised when errors occur during the OAuth
  flow (e.g. an invalid handle is provided, or validation failed). You should
  implement a `Plug.ErrorHandler` to catch and handle these exceptions
  gracefully.

  ## Example

  Example implementation showing how to set up the OAuth plug with proper
  session handling, error handling, and a callback function.

      defmodule ExampleOAuthPlug do
        use Plug.Router
        use Plug.ErrorHandler

        plug :put_secret_key_base

        plug Plug.Session,
          store: :cookie,
          key: "atex-oauth",
          signing_salt: "signing-salt"

        plug :match
        plug :dispatch

        forward "/oauth", to: Atex.OAuth.Plug, init_opts: [callback: {__MODULE__, :oauth_callback, []}]

        def oauth_callback(conn) do
          # Handle successful OAuth authentication
          conn
          |> put_resp_header("Location", "/dashboard")
          |> resp(307, "")
          |> send_resp()
        end

        def put_secret_key_base(conn, _) do
          put_in(
            conn.secret_key_base,
            "very long key base with at least 64 bytes"
          )
        end

        # Error handler for OAuth exceptions
        @impl Plug.ErrorHandler
        def handle_errors(conn, %{kind: :error, reason: %Atex.OAuth.Error{} = error, stack: _stack}) do
          status = case error.reason do
            reason when reason in [:missing_handle, :invalid_handle, :invalid_callback_request, :issuer_mismatch] -> 400
            _ -> 500
          end

          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(status, error.message)
        end

        # Fallback for other errors
        def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
          send_resp(conn, conn.status, "Something went wrong")
        end
      end

  ## Session Storage

  After successful authentication, the plug stores these in the session:

  - `:tokens` - The access token response containing access_token,
    refresh_token, did, and expires_at
  - `:dpop_nonce` -
  - `:dpop_key` - The DPoP JWK for generating DPoP proofs
  """
  require Logger
  use Plug.Router
  require Plug.Router
  alias Atex.OAuth
  alias Atex.{IdentityResolver, IdentityResolver.DIDDocument}

  @oauth_cookie_opts [path: "/", http_only: true, secure: true, same_site: "lax", max_age: 600]
  @session_name :atex_session

  def init(opts) do
    callback = Keyword.get(opts, :callback, nil)

    if !match?({_module, _function, _args}, callback) do
      raise "expected callback to be a MFA tuple"
    end

    opts
  end

  def call(conn, opts) do
    conn
    |> put_private(:atex_oauth_opts, opts)
    |> super(opts)
  end

  plug :match
  plug :dispatch

  get "/login" do
    conn = fetch_query_params(conn)
    handle = conn.query_params["handle"]

    if !handle do
      raise Atex.OAuth.Error,
        message: "Handle query parameter is required",
        reason: :missing_handle
    end

    case IdentityResolver.resolve(handle) do
      {:ok, identity} ->
        pds = DIDDocument.get_pds_endpoint(identity.document)
        {:ok, authz_server} = OAuth.get_authorization_server(pds)
        {:ok, authz_metadata} = OAuth.get_authorization_server_metadata(authz_server)
        state = OAuth.create_nonce()
        code_verifier = OAuth.create_nonce()

        case OAuth.create_authorization_url(
               authz_metadata,
               state,
               code_verifier,
               handle
             ) do
          {:ok, authz_url} ->
            conn
            |> put_resp_cookie("state", state, @oauth_cookie_opts)
            |> put_resp_cookie("code_verifier", code_verifier, @oauth_cookie_opts)
            |> put_resp_cookie("issuer", authz_metadata.issuer, @oauth_cookie_opts)
            |> put_resp_header("location", authz_url)
            |> send_resp(307, "")

          {:error, _err} ->
            raise Atex.OAuth.Error,
              message: "Failed to create authorization URL",
              reason: :authorization_url_failed
        end

      _err ->
        raise Atex.OAuth.Error, message: "Invalid or unresolvable handle", reason: :invalid_handle
    end
  end

  get "/client-metadata.json" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, JSON.encode_to_iodata!(OAuth.create_client_metadata()))
  end

  get "/callback" do
    conn = conn |> fetch_query_params() |> fetch_session()
    callback = Keyword.get(conn.private.atex_oauth_opts, :callback)
    cookies = get_cookies(conn)
    stored_state = cookies["state"]
    stored_code_verifier = cookies["code_verifier"]
    stored_issuer = cookies["issuer"]

    code = conn.query_params["code"]
    state = conn.query_params["state"]

    if !stored_state || !stored_code_verifier || !stored_issuer || (!code || !state) ||
         stored_state != state do
      raise Atex.OAuth.Error,
        message: "Invalid callback request: missing or mismatched state/code parameters",
        reason: :invalid_callback_request
    end

    with {:ok, authz_metadata} <- OAuth.get_authorization_server_metadata(stored_issuer),
         dpop_key <- JOSE.JWK.generate_key({:ec, "P-256"}),
         {:ok, tokens, nonce} <-
           OAuth.validate_authorization_code(
             authz_metadata,
             dpop_key,
             code,
             stored_code_verifier
           ),
         {:ok, identity} <- IdentityResolver.resolve(tokens.did),
         # Make sure pds' issuer matches the stored one (just in case)
         pds <- DIDDocument.get_pds_endpoint(identity.document),
         {:ok, authz_server} <- OAuth.get_authorization_server(pds),
         true <- authz_server == stored_issuer do
      session = %OAuth.Session{
        iss: authz_server,
        aud: pds,
        sub: tokens.did,
        access_token: tokens.access_token,
        refresh_token: tokens.refresh_token,
        expires_at: tokens.expires_at,
        dpop_key: dpop_key,
        dpop_nonce: nonce
      }

      case OAuth.SessionStore.insert(session) do
        :ok ->
          conn =
            conn
            |> delete_resp_cookie("state", @oauth_cookie_opts)
            |> delete_resp_cookie("code_verifier", @oauth_cookie_opts)
            |> delete_resp_cookie("issuer", @oauth_cookie_opts)
            |> put_session(@session_name, tokens.did)

          {mod, func, args} = callback
          apply(mod, func, [conn | args])

        {:error, reason} ->
          raise Atex.OAuth.Error,
            message: "Failed to store OAuth session, reason: #{reason}",
            reason: :session_store_failed
      end
    else
      false ->
        raise Atex.OAuth.Error,
          message: "OAuth issuer does not match PDS' authorization server",
          reason: :issuer_mismatch

      _err ->
        raise Atex.OAuth.Error,
          message: "Failed to validate authorization code or token",
          reason: :token_validation_failed
    end
  end

  # TODO: logout route
end
