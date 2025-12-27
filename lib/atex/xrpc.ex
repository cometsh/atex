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

      # OAuth-based client
      {:ok, oauth_client} = Atex.XRPC.OAuthClient.from_conn(conn)
      {:ok, response, oauth_client} = Atex.XRPC.get(oauth_client, "app.bsky.actor.getProfile", params: [actor: "user.bsky.social"])

  ## Unauthenticated requests

  Unauthenticated functions (`unauthed_get/3`, `unauthed_post/3`) do not require a client
  and work directly with endpoints:

      {:ok, response} = Atex.XRPC.unauthed_get("https://bsky.social", "com.atproto.sync.getHead", params: [did: "did:plc:..."])
  """

  alias Atex.XRPC.Client

  @doc """
  Perform a HTTP GET on a XRPC resource. Called a "query" in lexicons.

  Accepts any client that implements `Atex.XRPC.Client` and returns
  both the response and the (potentially updated) client.

  Can be called either with the XRPC operation name as a string, or with a lexicon
  struct (generated via `deflexicon`) for type safety and automatic parameter/response handling.

  When using a lexicon struct, the response body will be automatically converted to the
  corresponding type if an Output struct exists for the lexicon.

  ## Examples

      # Using string XRPC name
      {:ok, response, client} =
        Atex.XRPC.get(client, "app.bsky.actor.getProfile", params: [actor: "ovyerus.com"])

      # Using lexicon struct with typed construction
      {:ok, response, client} =
        Atex.XRPC.get(client, %App.Bsky.Actor.GetProfile{
          params: %App.Bsky.Actor.GetProfile.Params{actor: "ovyerus.com"}
        })
  """
  @spec get(Client.client(), String.t() | struct(), keyword()) ::
          {:ok, Req.Response.t(), Client.client()}
          | {:error, any(), Client.client()}
  def get(client, name, opts \\ [])

  def get(client, name, opts) when is_binary(name) do
    client.__struct__.get(client, name, opts)
  end

  def get(client, %{__struct__: module} = query, opts) do
    opts = if Map.get(query, :params), do: Keyword.put(opts, :params, query.params), else: opts
    output_struct = Module.concat(module, Output)
    output_exists = Code.ensure_loaded?(output_struct)

    case client.__struct__.get(client, module.id(), opts) do
      {:ok, %{status: 200} = response, client} ->
        if output_exists do
          case output_struct.from_json(response.body) do
            {:ok, output} ->
              {:ok, %{response | body: output}, client}

            err ->
              err
          end
        else
          {:ok, response, client}
        end

      {:ok, _, _} = ok ->
        ok

      err ->
        err
    end
  end

  @doc """
  Perform a HTTP POST on a XRPC resource. Called a "procedure" in lexicons.

  Accepts any client that implements `Atex.XRPC.Client` and returns both the
  response and the (potentially updated) client.

  Can be called either with the XRPC operation name as a string, or with a
  lexicon struct (generated via `deflexicon`) for type safety and automatic
  input/parameter mapping.

  When using a lexicon struct, the response body will be automatically converted
  to the corresponding type if an Output struct exists for the lexicon.

  ## Examples

      # Using string XRPC name
      {:ok, response, client} =
        Atex.XRPC.post(
          client,
          "com.atproto.repo.createRecord",
          json: %{
            repo: "did:plc:...",
            collection: "app.bsky.feed.post",
            rkey: Atex.TID.now() |> to_string(),
            record: %{
              text: "Hello World",
              createdAt: DateTime.to_iso8601(DateTime.utc_now())
            }
          }
        )

      # Using lexicon struct with typed construction
      {:ok, response, client} =
        Atex.XRPC.post(client, %Com.Atproto.Repo.CreateRecord{
          input: %Com.Atproto.Repo.CreateRecord.Input{
            repo: "did:plc:...",
            collection: "app.bsky.feed.post",
            rkey: Atex.TID.now() |> to_string(),
            record: %App.Bsky.Feed.Post{
              text: "Hello World!",
              createdAt: DateTime.to_iso8601(DateTime.utc_now())
            }
          }
        })
  """
  @spec post(Client.client(), String.t() | struct(), keyword()) ::
          {:ok, Req.Response.t(), Client.client()}
          | {:error, any(), Client.client()}
  def post(client, name, opts \\ [])

  def post(client, name, opts) when is_binary(name) do
    client.__struct__.post(client, name, opts)
  end

  def post(client, %{__struct__: module} = procedure, opts) do
    opts =
      opts
      |> then(
        &if Map.get(procedure, :params), do: Keyword.put(&1, :params, procedure.params), else: &1
      )
      |> then(
        &cond do
          Map.get(procedure, :input) -> Keyword.put(&1, :json, procedure.input)
          Map.get(procedure, :raw_input) -> Keyword.put(&1, :body, procedure.raw_input)
          true -> &1
        end
      )

    output_struct = Module.concat(module, Output)
    output_exists = Code.ensure_loaded?(output_struct)

    case client.__struct__.post(client, module.id(), opts) do
      {:ok, %{status: 200} = response, client} ->
        if output_exists do
          case output_struct.from_json(response.body) do
            {:ok, output} ->
              {:ok, %{response | body: output}, client}

            err ->
              err
          end
        else
          {:ok, response, client}
        end

      {:ok, _, _} = ok ->
        ok

      err ->
        err
    end
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

  @doc """
  Create an XRPC url based on an endpoint and a resource name.

  ## Example

      iex> Atex.XRPC.url("https://bsky.app", "app.bsky.actor.getProfile")
      "https://bsky.app/xrpc/app.bsky.actor.getProfile"
  """
  @spec url(String.t(), String.t()) :: String.t()
  def url(endpoint, resource) when is_binary(endpoint), do: "#{endpoint}/xrpc/#{resource}"
end
