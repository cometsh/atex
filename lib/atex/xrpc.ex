defmodule Atex.XRPC do
  alias Atex.XRPC

  # TODO: automatic user-agent, and env for changing it

  # TODO: consistent struct shape/protocol for Lexicon schemas so that user can pass in
  # an object (hopefully validated by its module) without needing to specify the
  # name & opts separately, and possibly verify the output response against it?

  # TODO: auto refresh, will need to return a client instance in each method.

  @doc """
  Perform a HTTP GET on a XRPC resource. Called a "query" in lexicons.
  """
  @spec get(XRPC.Client.t(), String.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, any()}
  def get(%XRPC.Client{} = client, name, opts \\ []) do
    opts = put_auth(opts, client.access_token)
    Req.get(url(client, name), opts)
  end

  @doc """
  Perform a HTTP POST on a XRPC resource. Called a "prodecure" in lexicons.
  """
  @spec post(XRPC.Client.t(), String.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, any()}
  def post(%XRPC.Client{} = client, name, opts \\ []) do
    # TODO: look through available HTTP clients and see if they have a
    # consistent way of providing JSON bodies with auto content-type. If not,
    # create one for adapters.
    opts = put_auth(opts, client.access_token)
    Req.post(url(client, name), opts)
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
  @spec url(XRPC.Client.t() | String.t(), String.t()) :: String.t()
  defp url(%XRPC.Client{endpoint: endpoint}, name), do: url(endpoint, name)
  defp url(endpoint, name) when is_binary(endpoint), do: "#{endpoint}/xrpc/#{name}"

  @doc """
  Put an `authorization` header into a keyword list of options to pass to a HTTP client.
  """
  @spec put_auth(keyword(), String.t()) :: keyword()
  def put_auth(opts, token),
    do: put_headers(opts, authorization: "Bearer #{token}")

  @spec put_headers(keyword(), keyword()) :: keyword()
  defp put_headers(opts, headers) do
    opts
    |> Keyword.put_new(:headers, [])
    |> Keyword.update(:headers, [], &Keyword.merge(&1, headers))
  end
end
