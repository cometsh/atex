defmodule Atex.XRPC.Client do
  @doc """
  Struct to store client information for ATProto XRPC.
  """

  alias Atex.XRPC
  use TypedStruct

  typedstruct do
    field :endpoint, String.t(), enforce: true
    field :access_token, String.t() | nil
    field :refresh_token, String.t() | nil
  end

  @doc """
  Create a new `Atex.XRPC.Client` from an endpoint, and optionally an
  access/refresh token.

  Endpoint should be the base URL of a PDS, or an AppView in the case of
  unauthenticated requests (like Bluesky's public API), e.g.
  `https://bsky.social`.
  """
  @spec new(String.t()) :: t()
  @spec new(String.t(), String.t() | nil) :: t()
  @spec new(String.t(), String.t() | nil, String.t() | nil) :: t()
  def new(endpoint, access_token \\ nil, refresh_token \\ nil) do
    %__MODULE__{endpoint: endpoint, access_token: access_token, refresh_token: refresh_token}
  end

  @doc """
  Create a new `Atex.XRPC.Client` by logging in with an `identifier` and
  `password` to fetch an initial pair of access & refresh tokens.

  Uses `com.atproto.server.createSession` under the hood, so `identifier` can be
  either a handle or a DID.

  ## Examples

      iex> Atex.XRPC.Client.login("https://bsky.social", "example.com", "password123")
      {:ok, %Atex.XRPC.Client{...}}
  """
  @spec login(String.t(), String.t(), String.t()) :: {:ok, t()} | XRPC.Adapter.error()
  @spec login(String.t(), String.t(), String.t(), String.t() | nil) ::
          {:ok, t()} | XRPC.Adapter.error()
  def login(endpoint, identifier, password, auth_factor_token \\ nil) do
    json =
      %{identifier: identifier, password: password}
      |> then(
        &if auth_factor_token do
          Map.merge(&1, %{authFactorToken: auth_factor_token})
        else
          &1
        end
      )

    response = XRPC.unauthed_post(endpoint, "com.atproto.server.createSession", json: json)

    case response do
      {:ok, %{"accessJwt" => access_token, "refreshJwt" => refresh_token}} ->
        {:ok, new(endpoint, access_token, refresh_token)}

      err ->
        err
    end
  end

  @doc """
  Request a new `refresh_token` for the given client.
  """
  @spec refresh(t()) :: {:ok, t()} | XRPC.Adapter.error()
  def refresh(%__MODULE__{endpoint: endpoint, refresh_token: refresh_token} = client) do
    response =
      XRPC.unauthed_post(
        endpoint,
        "com.atproto.server.refreshSession",
        XRPC.put_auth([], refresh_token)
      )

    case response do
      {:ok, %{"accessJwt" => access_token, "refreshJwt" => refresh_token}} ->
        %{client | access_token: access_token, refresh_token: refresh_token}

      err ->
        err
    end
  end
end
