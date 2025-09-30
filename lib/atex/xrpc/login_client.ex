defmodule Atex.XRPC.LoginClient do
  alias Atex.XRPC
  use TypedStruct

  @behaviour Atex.XRPC.Client

  typedstruct do
    field :endpoint, String.t(), enforce: true
    field :access_token, String.t() | nil
    field :refresh_token, String.t() | nil
  end

  @doc """
  Create a new `Atex.XRPC.LoginClient` from an endpoint, and optionally an
  existing access/refresh token.

  Endpoint should be the base URL of a PDS, or an AppView in the case of
  unauthenticated requests (like Bluesky's public API), e.g.
  `https://bsky.social`.
  """
  @spec new(String.t(), String.t() | nil, String.t() | nil) :: t()
  def new(endpoint, access_token \\ nil, refresh_token \\ nil) do
    %__MODULE__{endpoint: endpoint, access_token: access_token, refresh_token: refresh_token}
  end

  @doc """
  Create a new `Atex.XRPC.LoginClient` by logging in with an `identifier` and
  `password` to fetch an initial pair of access & refresh tokens.

  Also supports providing a MFA token in the situation that is required.

  Uses `com.atproto.server.createSession` under the hood, so `identifier` can be
  either a handle or a DID.

  ## Examples

      iex> Atex.XRPC.LoginClient.login("https://bsky.social", "example.com", "password123")
      {:ok, %Atex.XRPC.LoginClient{...}}
  """
  @spec login(String.t(), String.t(), String.t()) :: {:ok, t()} | {:error, any()}
  @spec login(String.t(), String.t(), String.t(), String.t() | nil) ::
          {:ok, t()} | {:error, any()}
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
      {:ok, %{body: %{"accessJwt" => access_token, "refreshJwt" => refresh_token}}} ->
        {:ok, new(endpoint, access_token, refresh_token)}

      err ->
        err
    end
  end

  @doc """
  Request a new `refresh_token` for the given client.
  """
  @spec refresh(t()) :: {:ok, t()} | {:error, any()}
  def refresh(%__MODULE__{endpoint: endpoint, refresh_token: refresh_token} = client) do
    request =
      Req.new(method: :post, url: XRPC.url(endpoint, "com.atproto.server.refreshSession"))
      |> put_auth(refresh_token)

    case Req.request(request) do
      {:ok, %{body: %{"accessJwt" => access_token, "refreshJwt" => refresh_token}}} ->
        {:ok, %{client | access_token: access_token, refresh_token: refresh_token}}

      {:ok, response} ->
        {:error, response}

      err ->
        err
    end
  end

  @impl true
  def get(%__MODULE__{} = client, resource, opts \\ []) do
    request(client, opts ++ [method: :get, url: XRPC.url(client.endpoint, resource)])
  end

  @impl true
  def post(%__MODULE__{} = client, resource, opts \\ []) do
    request(client, opts ++ [method: :post, url: XRPC.url(client.endpoint, resource)])
  end

  @spec request(t(), keyword()) :: {:ok, Req.Response.t(), t()} | {:error, any()}
  defp request(client, opts) do
    with {:ok, client} <- validate_client(client) do
      request = opts |> Req.new() |> put_auth(client.access_token)

      case Req.request(request) do
        {:ok, %{status: 200} = response} ->
          {:ok, response, client}

        {:ok, response} ->
          handle_failure(client, response, request)

        err ->
          err
      end
    end
  end

  @spec handle_failure(t(), Req.Response.t(), Req.Request.t()) ::
          {:ok, Req.Response.t(), t()} | {:error, any()}
  defp handle_failure(client, response, request) do
    IO.inspect(response, label: "got failure")

    if auth_error?(response.body) and client.refresh_token do
      case refresh(client) do
        {:ok, client} ->
          case Req.request(put_auth(request, client.access_token)) do
            {:ok, %{status: 200} = response} -> {:ok, response, client}
            {:ok, response} -> {:error, response}
            err -> err
          end

        err ->
          err
      end
    else
      {:error, response}
    end
  end

  @spec validate_client(t()) :: {:ok, t()} | {:error, any()}
  defp validate_client(%__MODULE__{access_token: nil}), do: {:error, :no_token}
  defp validate_client(%__MODULE__{} = client), do: {:ok, client}

  @spec auth_error?(body :: Req.Response.t()) :: boolean()
  defp auth_error?(%{status: status}) when status in [401, 403], do: true
  defp auth_error?(%{body: %{"error" => "InvalidToken"}}), do: true
  defp auth_error?(_response), do: false

  @spec put_auth(Req.Request.t(), String.t()) :: Req.Request.t()
  defp put_auth(request, token),
    do: Req.Request.put_header(request, "authorization", "Bearer #{token}")
end
