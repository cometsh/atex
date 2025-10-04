defmodule Atex.XRPC.OAuthClient do
  alias Atex.OAuth
  alias Atex.XRPC
  use TypedStruct

  @behaviour Atex.XRPC.Client

  typedstruct enforce: true do
    field :endpoint, String.t()
    field :issuer, String.t()
    field :access_token, String.t()
    field :refresh_token, String.t()
    field :did, String.t()
    field :expires_at, NaiveDateTime.t()
    field :dpop_nonce, String.t() | nil, enforce: false
    field :dpop_key, JOSE.JWK.t()
  end

  @doc """
  Create a new OAuthClient struct.
  """
  @spec new(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          NaiveDateTime.t(),
          JOSE.JWK.t(),
          String.t() | nil
        ) :: t()
  def new(endpoint, did, access_token, refresh_token, expires_at, dpop_key, dpop_nonce) do
    {:ok, issuer} = OAuth.get_authorization_server(endpoint)

    %__MODULE__{
      endpoint: endpoint,
      issuer: issuer,
      access_token: access_token,
      refresh_token: refresh_token,
      did: did,
      expires_at: expires_at,
      dpop_nonce: dpop_nonce,
      dpop_key: dpop_key
    }
  end

  @doc """
  Create an OAuthClient struct from a `Plug.Conn`.

  Requires the conn to have passed through `Plug.Session` and
  `Plug.Conn.fetch_session/2` so that the session can be acquired and have the
  `atex_oauth` key fetched from it.

  Returns `:error` if the state is missing or is not the expected shape.
  """
  @spec from_conn(Plug.Conn.t()) :: {:ok, t()} | :error
  def from_conn(%Plug.Conn{} = conn) do
    oauth_state = Plug.Conn.get_session(conn, :atex_oauth)

    case oauth_state do
      %{
        access_token: access_token,
        refresh_token: refresh_token,
        did: did,
        pds: pds,
        expires_at: expires_at,
        dpop_nonce: dpop_nonce,
        dpop_key: dpop_key
      } ->
        {:ok, new(pds, did, access_token, refresh_token, expires_at, dpop_key, dpop_nonce)}

      _ ->
        :error
    end
  end

  @doc """
  Updates a `Plug.Conn` session with the latest values from the client.

  Ideally should be called at the end of routes where XRPC calls occur, in case
  the client has transparently refreshed, so that the user is always up to date.
  """
  @spec update_plug(Plug.Conn.t(), t()) :: Plug.Conn.t()
  def update_plug(%Plug.Conn{} = conn, %__MODULE__{} = client) do
    Plug.Conn.put_session(conn, :atex_oauth, %{
      access_token: client.access_token,
      refresh_token: client.refresh_token,
      did: client.did,
      pds: client.endpoint,
      expires_at: client.expires_at,
      dpop_nonce: client.dpop_nonce,
      dpop_key: client.dpop_key
    })
  end

  @doc """
  Ask the client's OAuth server for a new set of auth tokens.

  You shouldn't need to call this manually for the most part, the client does
  it's best to refresh automatically when it needs to.
  """
  @spec refresh(t()) :: {:ok, t()} | {:error, any()}
  def refresh(%__MODULE__{} = client) do
    with {:ok, authz_server} <- OAuth.get_authorization_server(client.endpoint),
         {:ok, %{token_endpoint: token_endpoint}} <-
           OAuth.get_authorization_server_metadata(authz_server) do
      case OAuth.refresh_token(
             client.refresh_token,
             client.dpop_key,
             client.issuer,
             token_endpoint
           ) do
        {:ok, tokens, nonce} ->
          {:ok,
           %{
             client
             | access_token: tokens.access_token,
               refresh_token: tokens.refresh_token,
               dpop_nonce: nonce
           }}

        err ->
          err
      end
    end
  end

  @doc """
  See `Atex.XRPC.get/3`.
  """
  @impl true
  def get(%__MODULE__{} = client, resource, opts \\ []) do
    request(client, opts ++ [method: :get, url: XRPC.url(client.endpoint, resource)])
  end

  @doc """
  See `Atex.XRPC.post/3`.
  """
  @impl true
  def post(%__MODULE__{} = client, resource, opts \\ []) do
    request(client, opts ++ [method: :post, url: XRPC.url(client.endpoint, resource)])
  end

  @spec request(t(), keyword()) :: {:ok, Req.Response.t(), t()} | {:error, any(), any()}
  defp request(client, opts) do
    # Preemptively refresh token if it's about to expire
    with {:ok, client} <- maybe_refresh(client) do
      request = opts |> Req.new() |> put_auth(client.access_token)

      case OAuth.request_protected_dpop_resource(
             request,
             client.issuer,
             client.access_token,
             client.dpop_key,
             client.dpop_nonce
           ) do
        {:ok, %{status: 200} = response, nonce} ->
          client = %{client | dpop_nonce: nonce}
          {:ok, response, client}

        {:ok, response, nonce} ->
          client = %{client | dpop_nonce: nonce}
          handle_failure(client, response, request)

        err ->
          err
      end
    end
  end

  @spec handle_failure(t(), Req.Response.t(), Req.Request.t()) ::
          {:ok, Req.Response.t(), t()} | {:error, any(), t()}
  defp handle_failure(client, response, request) do
    IO.inspect(response, label: "got failure")

    if auth_error?(response.body) and client.refresh_token do
      case refresh(client) do
        {:ok, client} ->
          case OAuth.request_protected_dpop_resource(
                 request,
                 client.issuer,
                 client.access_token,
                 client.dpop_key,
                 client.dpop_nonce
               ) do
            {:ok, %{status: 200} = response, nonce} ->
              {:ok, response, %{client | dpop_nonce: nonce}}

            {:ok, response, nonce} ->
              {:error, response, %{client | dpop_nonce: nonce}}

            {:error, err} ->
              {:error, err, client}
          end

        err ->
          err
      end
    else
      {:error, response, client}
    end
  end

  @spec maybe_refresh(t(), integer()) :: {:ok, t()} | {:error, any()}
  defp maybe_refresh(%__MODULE__{expires_at: expires_at} = client, buffer_minutes \\ 5) do
    if token_expiring_soon?(expires_at, buffer_minutes) do
      refresh(client)
    else
      {:ok, client}
    end
  end

  @spec token_expiring_soon?(NaiveDateTime.t(), integer()) :: boolean()
  defp token_expiring_soon?(expires_at, buffer_minutes) do
    now = NaiveDateTime.utc_now()
    expiry_threshold = NaiveDateTime.add(now, buffer_minutes * 60, :second)

    NaiveDateTime.compare(expires_at, expiry_threshold) in [:lt, :eq]
  end

  @spec auth_error?(body :: Req.Response.t()) :: boolean()
  defp auth_error?(%{status: status}) when status in [401, 403], do: true
  defp auth_error?(%{body: %{"error" => "InvalidToken"}}), do: true
  defp auth_error?(_response), do: false

  @spec put_auth(Req.Request.t(), String.t()) :: Req.Request.t()
  defp put_auth(request, token),
    do: Req.Request.put_header(request, "authorization", "DPoP #{token}")
end
