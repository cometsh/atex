defmodule Atex.XRPC do
  @moduledoc """
  XRPC client module for AT Protocol RPC calls.

  This module provides both authenticated and unauthenticated access to AT Protocol
  XRPC endpoints. The authenticated functions (`get/3`, `post/3`) work with any
  client that implements the `Atex.XRPC.Client`.

  ## Example usage

      # Login-based client
      {:ok, client} = Atex.XRPC.LoginClient.login("https://bsky.social", "user.bsky.social", "password")
      {:ok, response, client} = Atex.XRPC.get(client, "app.bsky.actor.getProfile", params: [actor: "user.bsky.social"])

      # OAuth-based client (coming next)
      oauth_client = Atex.XRPC.OAuthClient.new_from_oauth_tokens(endpoint, access_token, refresh_token, dpop_key)
      {:ok, response, oauth_client} = Atex.XRPC.get(oauth_client, "app.bsky.actor.getProfile", params: [actor: "user.bsky.social"])

  ## Unauthenticated requests

  Unauthenticated functions (`unauthed_get/3`, `unauthed_post/3`) do not require a client
  and work directly with endpoints:

      {:ok, response} = Atex.XRPC.unauthed_get("https://bsky.social", "com.atproto.sync.getHead", params: [did: "did:plc:..."])
  """

  @doc """
  Perform a HTTP GET on a XRPC resource. Called a "query" in lexicons.

  Accepts any client that implements `Atex.XRPC.Client` and returns
  both the response and the (potentially updated) client.
  """
  @spec get(Atex.XRPC.Client.client(), String.t(), keyword()) ::
          {:ok, Req.Response.t(), Atex.XRPC.Client.client()}
          | {:error, any(), Atex.XRPC.Client.client()}
  def get(client, name, opts \\ []) do
    client.__struct__.get(client, name, opts)
  end

  @doc """
  Perform a HTTP POST on a XRPC resource. Called a "prodecure" in lexicons.

  Accepts any client that implements `Atex.XRPC.Client` and returns
  both the response and the (potentially updated) client.
  """
  @spec post(Atex.XRPC.Client.client(), String.t(), keyword()) ::
          {:ok, Req.Response.t(), Atex.XRPC.Client.client()}
          | {:error, any(), Atex.XRPC.Client.client()}
  def post(client, name, opts \\ []) do
    client.__struct__.post(client, name, opts)
  end

  @doc """
  Like `get/3` but is unauthenticated by default.
  """
  @spec unauthed_get(String.t(), String.t(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, any()}
  def unauthed_get(endpoint, name, opts \\ []) do
    Req.get(url(endpoint, name), opts)
  end

  @doc """
  Like `post/3` but is unauthenticated by default.
  """
  @spec unauthed_post(String.t(), String.t(), keyword()) ::
          {:ok, Req.Response.t()} | {:error, any()}
  def unauthed_post(endpoint, name, opts \\ []) do
    Req.post(url(endpoint, name), opts)
  end

  # TODO: use URI module for joining instead?
  @doc """
  Create an XRPC url based on an endpoint and a resource name.

  ## Example

      iex> Atex.XRPC.url("https://bsky.app", "app.bsky.actor.getProfile")
      "https://bsky.app/xrpc/app.bsky.actor.getProfile"
  """
  @spec url(String.t(), String.t()) :: String.t()
  def url(endpoint, resource) when is_binary(endpoint), do: "#{endpoint}/xrpc/#{resource}"
end
