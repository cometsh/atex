defmodule Atex.XRPC.ServiceAuthClient do
  @moduledoc """
  An XRPC client that uses a inter-service auth JWT to interact with another
  service on a user's behalf. See `Atex.ServiceAuth` and
  [`com.atproto.server.getServiceAuth`](https://github.com/bluesky-social/atproto/blob/main/lexicons/com/atproto/server/getServiceAuth.json)
  for more information.

  ## Usage

      client = Atex.XRPC.ServiceAuthClient.new("<jwt>")
      {:ok, response, _} = Atex.XRPC.get(client, "com.example.authenticatedXRPC")
  """

  alias Atex.{DID.Document, IdentityResolver, XRPC}

  use TypedStruct
  @behaviour Atex.XRPC.Client

  typedstruct do
    field :token, String.t(), enforce: true
  end

  @doc """
  Create a new `Atex.XRPC.ServiceAuthClient` from a service auth JWT.

  The JWT is stored as-is; no validation is performed at construction time.
  Endpoint resolution and token use happen on the first (and only valid) call
  to `get/3` or `post/3`.

  ## Examples

      iex> Atex.XRPC.ServiceAuthClient.new("eyJ...")
      %Atex.XRPC.ServiceAuthClient{token: "eyJ..."}
  """
  @spec new(String.t()) :: t()
  def new(token) when is_binary(token), do: %__MODULE__{token: token}

  @impl true
  def get(%__MODULE__{} = client, resource, opts \\ []) do
    with {:ok, endpoint} <- resolve_endpoint(client) do
      request(client, opts ++ [method: :get, url: XRPC.url(endpoint, resource)])
    end
  end

  @impl true
  def post(%__MODULE__{} = client, resource, opts \\ []) do
    with {:ok, endpoint} <- resolve_endpoint(client) do
      request(client, opts ++ [method: :post, url: XRPC.url(endpoint, resource)])
    end
  end

  @spec request(t(), keyword()) :: {:ok, Req.Response.t(), t()} | {:error, any(), t()}
  defp request(client, opts) do
    req =
      opts
      |> Req.new()
      |> Atex.XRPC.attach_user_agent()
      |> put_auth(client.token)
      |> Atex.Telemetry.attach_req_plugin(client_type: :service_auth)

    case Req.request(req) do
      {:ok, response} -> {:ok, response, client}
      {:error, reason} -> {:error, reason, client}
    end
  end

  @spec resolve_endpoint(t()) :: {:ok, String.t()} | {:error, any()}
  defp resolve_endpoint(%__MODULE__{token: token}) do
    %{fields: %{"aud" => aud}} = JOSE.JWT.peek(token)

    with {:ok, identity} <- IdentityResolver.resolve(aud),
         endpoint when not is_nil(endpoint) <- Document.get_pds_endpoint(identity.document) do
      {:ok, endpoint}
    else
      nil -> {:error, :no_pds_endpoint}
      err -> err
    end
  end

  @spec put_auth(Req.Request.t(), String.t()) :: Req.Request.t()
  defp put_auth(request, token),
    do: Req.Request.put_header(request, "authorization", "Bearer #{token}")
end
