defmodule Atex.ServiceAuth.JTICache do
  @moduledoc """
  Behaviour and compile-time dispatch for tracking used `jti` (JWT ID) nonces
  from service auth tokens, preventing replay attacks.

  Implementations are responsible for:

  - Storing a `jti` alongside its expiry so that entries can be evicted once
    the corresponding token has naturally expired (avoiding unbounded growth).
  - Returning `:seen` when a `jti` has already been recorded, and `:ok` when it
    is new (and recording it atomically).

  ## Configuration

  The active implementation is resolved at compile time:

  ```elixir
  config :atex, :jti_cache, Atex.ServiceAuth.JTICache.ETS
  ```

  Defaults to `Atex.ServiceAuth.JTICache.ETS` when not configured.
  """

  @cache Application.compile_env(:atex, :jti_cache, Atex.ServiceAuth.JTICache.ETS)

  @doc """
  Record a `jti` as seen. The implementation must store it until at least
  `expires_at` (a Unix timestamp integer) so that expired tokens cannot be
  replayed before the entry is evicted.

  Returns `:ok` if this is the first time the `jti` has been seen, or `:seen`
  if it was already present.
  """
  @callback put(jti :: String.t(), expires_at :: integer()) :: :ok | :seen

  @doc """
  Check whether a `jti` has already been seen without modifying the cache.

  Returns `:ok` if unseen, `:seen` if already present.
  """
  @callback get(jti :: String.t()) :: :ok | :seen

  @doc """
  Get the child specification for starting the cache in a supervision tree.
  """
  @callback child_spec(any()) :: Supervisor.child_spec()

  defdelegate put(jti, expires_at), to: @cache
  defdelegate get(jti), to: @cache
  @doc false
  defdelegate child_spec(opts), to: @cache
end
