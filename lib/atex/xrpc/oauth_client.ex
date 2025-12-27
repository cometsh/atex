defmodule Atex.XRPC.OAuthClient do
  @moduledoc """
  OAuth client for making authenticated XRPC requests to AT Protocol servers.

  The client contains a user's DID and talks to `Atex.OAuth.SessionStore` to
  retrieve sessions internally to make requests. As a result, it will only work
  for users that have gone through an OAuth flow; see `Atex.OAuth.Plug` for an
  existing method of doing that.

  The entire OAuth session lifecycle is handled transparently, with the access
  token being refreshed automatically as required.

  ## Usage

      # Create from an existing OAuth session
      {:ok, client} = Atex.XRPC.OAuthClient.new("did:plc:abc123")

      # Or extract from a Plug.Conn after OAuth flow
      {:ok, client} = Atex.XRPC.OAuthClient.from_conn(conn)

      # Make XRPC requests
      {:ok, response, client} = Atex.XRPC.get(client, "com.atproto.repo.listRecords")
  """

  alias Atex.OAuth
  use TypedStruct

  @behaviour Atex.XRPC.Client

  typedstruct enforce: true do
    field :did, String.t()
  end

  @doc """
  Create a new OAuthClient from a DID.

  Validates that an OAuth session exists for the given DID in the session store
  before returning the client struct.

  ## Examples

      iex> Atex.XRPC.OAuthClient.new("did:plc:abc123")
      {:ok, %Atex.XRPC.OAuthClient{did: "did:plc:abc123"}}

      iex> Atex.XRPC.OAuthClient.new("did:plc:nosession")
      {:error, :not_found}

  """
  @spec new(String.t()) :: {:ok, t()} | {:error, atom()}
  def new(did) do
    # Make sure session exists before returning a struct
    case Atex.OAuth.SessionStore.get(did) do
      {:ok, _session} ->
        {:ok, %__MODULE__{did: did}}

      err ->
        err
    end
  end

  @doc """
  Create an OAuthClient from a `Plug.Conn`.

  Extracts the DID from the session (stored under `:atex_session` key) and validates
  that the OAuth session is still valid. If the token is expired or expiring soon,
  it attempts to refresh it.

  Requires the conn to have passed through `Plug.Session` and `Plug.Conn.fetch_session/2`.

  ## Returns

  - `{:ok, client}` - Successfully created client
  - `{:error, :reauth}` - Session exists but refresh failed, user needs to re-authenticate
  - `:error` - No session found in conn

  ## Examples

      # After OAuth flow completes
      conn = Plug.Conn.put_session(conn, :atex_session, "did:plc:abc123")
      {:ok, client} = Atex.XRPC.OAuthClient.from_conn(conn)

  """
  @spec from_conn(Plug.Conn.t()) :: {:ok, t()} | :error | {:error, atom()}
  def from_conn(%Plug.Conn{} = conn) do
    oauth_did = Plug.Conn.get_session(conn, :atex_session)

    case oauth_did do
      did when is_binary(did) ->
        client = %__MODULE__{did: did}

        with_session_lock(client, fn ->
          case maybe_refresh(client) do
            {:ok, _session} -> {:ok, client}
            _ -> {:error, :reauth}
          end
        end)

      _ ->
        :error
    end
  end

  @doc """
  Ask the client's OAuth server for a new set of auth tokens.

  Fetches the session, refreshes the tokens, creates a new session with the
  updated tokens, stores it, and returns the new session.

  You shouldn't need to call this manually for the most part, the client does
  its best to refresh automatically when it needs to.

  This function acquires a lock on the session to prevent concurrent refresh attempts.
  """
  @spec refresh(client :: t()) :: {:ok, OAuth.Session.t()} | {:error, any()}
  def refresh(%__MODULE__{} = client) do
    with_session_lock(client, fn ->
      do_refresh(client)
    end)
  end

  @spec do_refresh(t()) :: {:ok, OAuth.Session.t()} | {:error, any()}
  defp do_refresh(%__MODULE__{did: did}) do
    with {:ok, session} <- OAuth.SessionStore.get(did),
         {:ok, authz_server} <- OAuth.get_authorization_server(session.aud),
         {:ok, %{token_endpoint: token_endpoint}} <-
           OAuth.get_authorization_server_metadata(authz_server) do
      case OAuth.refresh_token(
             session.refresh_token,
             session.dpop_key,
             session.iss,
             token_endpoint
           ) do
        {:ok, tokens, nonce} ->
          new_session = %OAuth.Session{
            iss: session.iss,
            aud: session.aud,
            sub: tokens.did,
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token,
            expires_at: tokens.expires_at,
            dpop_key: session.dpop_key,
            dpop_nonce: nonce
          }

          case OAuth.SessionStore.update(new_session) do
            :ok -> {:ok, new_session}
            err -> err
          end

        err ->
          err
      end
    end
  end

  @spec maybe_refresh(t(), integer()) :: {:ok, OAuth.Session.t()} | {:error, any()}
  defp maybe_refresh(%__MODULE__{did: did} = client, buffer_minutes \\ 5) do
    with {:ok, session} <- OAuth.SessionStore.get(did) do
      if token_expiring_soon?(session.expires_at, buffer_minutes) do
        do_refresh(client)
      else
        {:ok, session}
      end
    end
  end

  @spec token_expiring_soon?(NaiveDateTime.t(), integer()) :: boolean()
  defp token_expiring_soon?(expires_at, buffer_minutes) do
    now = NaiveDateTime.utc_now()
    expiry_threshold = NaiveDateTime.add(now, buffer_minutes * 60, :second)

    NaiveDateTime.compare(expires_at, expiry_threshold) in [:lt, :eq]
  end

  @doc """
  Make a GET request to an XRPC endpoint.

  See `Atex.XRPC.get/3` for details.
  """
  @impl true
  def get(%__MODULE__{} = client, resource, opts \\ []) do
    # TODO: Keyword.valiate to make sure :method isn't passed?
    request(client, resource, opts ++ [method: :get])
  end

  @doc """
  Make a POST request to an XRPC endpoint.

  See `Atex.XRPC.post/3` for details.
  """
  @impl true
  def post(%__MODULE__{} = client, resource, opts \\ []) do
    # Ditto
    request(client, resource, opts ++ [method: :post])
  end

  defp request(%__MODULE__{} = client, resource, opts) do
    with_session_lock(client, fn ->
      case maybe_refresh(client) do
        {:ok, session} ->
          url = Atex.XRPC.url(session.aud, resource)

          request =
            opts
            |> Keyword.put(:url, url)
            |> Req.new()
            |> Req.Request.put_header("authorization", "DPoP #{session.access_token}")

          case OAuth.request_protected_dpop_resource(
                 request,
                 session.iss,
                 session.access_token,
                 session.dpop_key,
                 session.dpop_nonce
               ) do
            {:ok, %{status: 200} = response, nonce} ->
              update_session_nonce(session, nonce)
              {:ok, response, client}

            {:ok, response, nonce} ->
              update_session_nonce(session, nonce)
              handle_failure(client, request, response)

            err ->
              err
          end

        err ->
          err
      end
    end)
  end

  # Execute a function with an exclusive lock on the session identified by the
  # client's DID. This ensures that concurrent requests for the same user don't
  # race during token refresh.
  @spec with_session_lock(t(), (-> result)) :: result when result: any()
  defp with_session_lock(%__MODULE__{did: did}, fun) do
    Mutex.with_lock(Atex.SessionMutex, did, fun)
  end

  defp handle_failure(client, request, response) do
    if auth_error?(response) do
      case do_refresh(client) do
        {:ok, session} ->
          case OAuth.request_protected_dpop_resource(
                 request,
                 session.iss,
                 session.access_token,
                 session.dpop_key,
                 session.dpop_nonce
               ) do
            {:ok, %{status: 200} = response, nonce} ->
              update_session_nonce(session, nonce)
              {:ok, response, client}

            {:ok, response, _nonce} ->
              if auth_error?(response) do
                # We tried to refresh the token once but it's still failing
                # Clear session and prompt dev to reauth or something
                OAuth.SessionStore.delete(session)
                {:error, response, :expired}
              else
                {:error, response, client}
              end

            err ->
              err
          end

        err ->
          err
      end
    else
      {:error, response, client}
    end
  end

  @spec auth_error?(Req.Response.t()) :: boolean()
  defp auth_error?(%{status: 401, headers: %{"www-authenticate" => [www_auth]}}),
    do:
      (String.starts_with?(www_auth, "Bearer") or String.starts_with?(www_auth, "DPoP")) and
        String.contains?(www_auth, "error=\"invalid_token\"")

  defp auth_error?(_resp), do: false

  defp update_session_nonce(session, nonce) do
    session = %{session | dpop_nonce: nonce}
    :ok = OAuth.SessionStore.update(session)
    session
  end
end
