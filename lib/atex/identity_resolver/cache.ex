defmodule Atex.IdentityResolver.Cache do
  # TODO: need the following:
  # did -> handle mapping
  # handle -> did mapping
  # did -> document mapping?
  # User should be able to call a single function to fetch all info for either did and handle, including the link between them.
  # Need some sort of TTL so that we can refresh as necessary
  alias Atex.IdentityResolver.Identity

  @cache Application.compile_env(:atex, :identity_cache, Atex.IdentityResolver.Cache.ETS)

  @doc """
  Add a new identity to the cache. Can also be used to update an identity that may already exist.

  Returns the input `t:Atex.IdentityResolver.Identity.t/0`.
  """
  @callback insert(identity :: Identity.t()) :: Identity.t()

  @doc """
  Retrieve an identity from the cache by DID *or* handle.
  """
  @callback get(String.t()) :: {:ok, Identity.t()} | {:error, atom()}

  @doc """
  Delete an identity in the cache.
  """
  @callback delete(String.t()) :: :noop | Identity.t()

  @doc """
  Get the child specification for starting the cache in a supervision tree.
  """
  @callback child_spec(any()) :: Supervisor.child_spec()

  defdelegate get(identifier), to: @cache

  @doc false
  defdelegate insert(payload), to: @cache
  @doc false
  defdelegate delete(snowflake), to: @cache
  @doc false
  defdelegate child_spec(opts), to: @cache
end
