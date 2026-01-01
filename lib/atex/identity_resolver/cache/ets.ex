defmodule Atex.IdentityResolver.Cache.ETS do
  @moduledoc """
  ConCache-based implementation for Identity Resolver caching.

  Stores identity information (DID and handle mappings) with a 1-hour TTL.
  Uses two separate cache entries per identity to allow lookups by either DID or handle.
  """

  alias Atex.IdentityResolver.Identity
  @behaviour Atex.IdentityResolver.Cache
  use Supervisor

  @cache :atex_identities_cache
  @ttl_ms :timer.hours(1)

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      {ConCache,
       [
         name: @cache,
         ttl_check_interval: :timer.minutes(5),
         global_ttl: @ttl_ms
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @impl Atex.IdentityResolver.Cache
  @spec insert(Identity.t()) :: Identity.t()
  def insert(identity) do
    ConCache.put(@cache, {:did, identity.did}, identity)
    ConCache.put(@cache, {:handle, identity.handle}, identity)
    identity
  end

  @impl Atex.IdentityResolver.Cache
  @spec get(String.t()) :: {:ok, Identity.t()} | {:error, atom()}
  def get(identifier) do
    case ConCache.get(@cache, {:did, identifier}) do
      nil ->
        case ConCache.get(@cache, {:handle, identifier}) do
          nil -> {:error, :not_found}
          identity -> {:ok, identity}
        end

      identity ->
        {:ok, identity}
    end
  end

  @impl Atex.IdentityResolver.Cache
  @spec delete(String.t()) :: :noop | Identity.t()
  def delete(identifier) do
    case get(identifier) do
      {:ok, identity} ->
        ConCache.delete(@cache, {:did, identity.did})
        ConCache.delete(@cache, {:handle, identity.handle})
        identity

      _ ->
        :noop
    end
  end
end
