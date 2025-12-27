defmodule Atex.OAuth.Cache do
  @moduledoc """
  TTL cache for OAuth authorization server information.

  This module manages two separate ConCache instances:
  - Authorization server cache (stores PDS -> authz server mappings)
  - Authorization metadata cache (stores authz server -> metadata mappings)

  Both caches use a 1-hour TTL to reduce load on third-party PDSs.
  """

  use Supervisor

  @authz_server_cache :oauth_authz_server_cache
  @authz_metadata_cache :oauth_authz_metadata_cache
  @ttl_ms :timer.hours(1)

  @doc """
  Starts the OAuth cache supervisor.
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      Supervisor.child_spec(
        {ConCache,
         [
           name: @authz_server_cache,
           ttl_check_interval: :timer.minutes(5),
           global_ttl: @ttl_ms
         ]},
        id: :authz_server_cache
      ),
      Supervisor.child_spec(
        {ConCache,
         [
           name: @authz_metadata_cache,
           ttl_check_interval: :timer.seconds(30),
           global_ttl: @ttl_ms
         ]},
        id: :authz_metadata_cache
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Get authorization server from cache.

  ## Parameters

    - `pds_host` - Base URL of the PDS (e.g., "https://bsky.social")

  ## Returns

    - `{:ok, authorization_server}` - Successfully retrieved from cache
    - `{:error, :not_found}` - Not present in cache
  """
  @spec get_authorization_server(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_authorization_server(pds_host) do
    case ConCache.get(@authz_server_cache, pds_host) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  @doc """
  Store authorization server in cache.

  ## Parameters

    - `pds_host` - Base URL of the PDS
    - `authorization_server` - Authorization server URL to cache

  ## Returns

    - `:ok`
  """
  @spec set_authorization_server(String.t(), String.t()) :: :ok
  def set_authorization_server(pds_host, authorization_server) do
    ConCache.put(@authz_server_cache, pds_host, authorization_server)
    :ok
  end

  @doc """
  Get authorization server metadata from cache.

  ## Parameters

    - `issuer` - Authorization server issuer URL

  ## Returns

    - `{:ok, metadata}` - Successfully retrieved from cache
    - `{:error, :not_found}` - Not present in cache
  """
  @spec get_authorization_server_metadata(String.t()) ::
          {:ok, Atex.OAuth.authorization_metadata()} | {:error, :not_found}
  def get_authorization_server_metadata(issuer) do
    case ConCache.get(@authz_metadata_cache, issuer) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  @doc """
  Store authorization server metadata in cache.

  ## Parameters

    - `issuer` - Authorization server issuer URL
    - `metadata` - Authorization server metadata to cache

  ## Returns

    - `:ok`
  """
  @spec set_authorization_server_metadata(String.t(), Atex.OAuth.authorization_metadata()) :: :ok
  def set_authorization_server_metadata(issuer, metadata) do
    ConCache.put(@authz_metadata_cache, issuer, metadata)
    :ok
  end
end
