defmodule Atex.XRPC.UnauthedClient do
  @moduledoc """
  An XRPC client that doesn't perform any authentication to a service.
  Can be used for public APIs like `public.api.bsky.app`, or performing
  public reads from PDSes.

  ## Usage

      client = Atex.XRPC.UnauthedClient.new("https://public.api.bsky.app")
      {:ok, response, client} = Atex.XRPC.get(client, "app.bsky.actor.getProfile", params: [actor: "ovyerus.com"])
  """

  use TypedStruct
  @behaviour Atex.XRPC.Client

  typedstruct do
    field :endpoint, String.t(), enforce: true
  end

  @doc """
  Create a new `Atex.XRPC.UnauthedClient`.
  """
  @spec new(String.t()) :: t()
  def new(endpoint) when is_binary(endpoint), do: %__MODULE__{endpoint: endpoint}

  @impl true
  def get(%__MODULE__{endpoint: endpoint} = client, resource, opts \\ []) do
    (opts ++ [method: :get, url: Atex.XRPC.url(endpoint, resource)])
    |> Req.new()
    |> Atex.XRPC.attach_user_agent()
    |> Atex.Telemetry.attach_req_plugin(client_type: :unauthed)
    |> Req.request()
    |> case do
      {:ok, response} -> {:ok, response, client}
      {:error, reason} -> {:error, reason, client}
    end
  end

  @impl true
  def post(%__MODULE__{endpoint: endpoint} = client, resource, opts \\ []) do
    (opts ++ [method: :post, url: Atex.XRPC.url(endpoint, resource)])
    |> Req.new()
    |> Atex.XRPC.attach_user_agent()
    |> Atex.Telemetry.attach_req_plugin(client_type: :unauthed)
    |> Req.request()
    |> case do
      {:ok, response} -> {:ok, response, client}
      {:error, reason} -> {:error, reason, client}
    end
  end
end
