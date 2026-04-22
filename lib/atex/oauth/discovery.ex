defmodule Atex.OAuth.Discovery do
  @moduledoc """
  Authorization server discovery for AT Protocol OAuth.

  Resolves a PDS to its authorization server and fetches authorization server
  metadata. Results are cached for 1 hour via `Atex.OAuth.Cache`.
  """

  alias Atex.OAuth.Cache

  @doc """
  Fetch the authorization server for a given Personal Data Server (PDS).

  Makes a request to the PDS's `.well-known/oauth-protected-resource` endpoint.
  Results are cached for 1 hour to reduce load on third-party PDSs.

  ## Parameters

  - `pds_host` - Base URL of the PDS (e.g., `"https://bsky.social"`)
  - `fresh` - If `true`, bypasses the cache and fetches fresh data (default: `false`)

  ## Returns

  - `{:ok, authorization_server}` - Successfully discovered authorization server URL
  - `{:error, :invalid_metadata}` - Server returned invalid metadata
  - `{:error, reason}` - Error discovering authorization server
  """
  @spec get_authorization_server(String.t(), boolean()) :: {:ok, String.t()} | {:error, any()}
  def get_authorization_server(pds_host, fresh \\ false) do
    if fresh do
      fetch_authorization_server(pds_host)
    else
      case Cache.get_authorization_server(pds_host) do
        {:ok, authz_server} -> {:ok, authz_server}
        {:error, :not_found} -> fetch_authorization_server(pds_host)
      end
    end
  end

  @doc """
  Fetch the metadata for an OAuth authorization server.

  Retrieves the metadata from `.well-known/oauth-authorization-server`.
  Results are cached for 1 hour.

  ## Parameters

  - `issuer` - Authorization server issuer URL
  - `fresh` - If `true`, bypasses the cache and fetches fresh data (default: `false`)

  ## Returns

  - `{:ok, metadata}` - Successfully retrieved authorization server metadata
  - `{:error, :invalid_metadata}` - Server returned invalid metadata
  - `{:error, :invalid_issuer}` - Issuer mismatch in metadata
  - `{:error, any()}` - Other error fetching metadata
  """
  @spec get_authorization_server_metadata(String.t(), boolean()) ::
          {:ok, Atex.OAuth.Flow.authorization_metadata()} | {:error, any()}
  def get_authorization_server_metadata(issuer, fresh \\ false) do
    if fresh do
      fetch_authorization_server_metadata(issuer)
    else
      case Cache.get_authorization_server_metadata(issuer) do
        {:ok, metadata} -> {:ok, metadata}
        {:error, :not_found} -> fetch_authorization_server_metadata(issuer)
      end
    end
  end

  @spec fetch_authorization_server(String.t()) :: {:ok, String.t()} | {:error, any()}
  defp fetch_authorization_server(pds_host) do
    result =
      "#{pds_host}/.well-known/oauth-protected-resource"
      |> Req.get()
      |> case do
        # TODO: what to do when multiple authorization servers?
        {:ok, %{body: %{"authorization_servers" => [authz_server | _]}}} ->
          {:ok, authz_server}

        {:ok, _} ->
          {:error, :invalid_metadata}

        err ->
          err
      end

    case result do
      {:ok, authz_server} ->
        Cache.set_authorization_server(pds_host, authz_server)
        {:ok, authz_server}

      error ->
        error
    end
  end

  @spec fetch_authorization_server_metadata(String.t()) ::
          {:ok, Atex.OAuth.Flow.authorization_metadata()} | {:error, any()}
  defp fetch_authorization_server_metadata(issuer) do
    result =
      "#{issuer}/.well-known/oauth-authorization-server"
      |> Req.get()
      |> case do
        {:ok,
         %{
           body: %{
             "issuer" => metadata_issuer,
             "pushed_authorization_request_endpoint" => par_endpoint,
             "token_endpoint" => token_endpoint,
             "authorization_endpoint" => authorization_endpoint,
             "revocation_endpoint" => revocation_endpoint
           }
         }} ->
          if issuer != metadata_issuer do
            {:error, :invalid_issuer}
          else
            {:ok,
             %{
               issuer: metadata_issuer,
               par_endpoint: par_endpoint,
               token_endpoint: token_endpoint,
               authorization_endpoint: authorization_endpoint,
               revocation_endpoint: revocation_endpoint
             }}
          end

        {:ok, _} ->
          {:error, :invalid_metadata}

        err ->
          err
      end

    case result do
      {:ok, metadata} ->
        Cache.set_authorization_server_metadata(issuer, metadata)
        {:ok, metadata}

      error ->
        error
    end
  end
end
