defmodule Atex.ServiceAuth.JTICache.ETS do
  @moduledoc """
  ConCache-backed implementation of `Atex.ServiceAuth.JTICache`.

  Each `jti` is stored with a per-item TTL derived from the token's own `exp`
  claim, so entries are evicted automatically once the corresponding token could
  no longer be presented as valid. This keeps memory use proportional to the
  number of currently-live tokens rather than growing without bound.

  The TTL check interval defaults to 30 seconds and can be overridden:

  ```elixir
  config :atex, Atex.ServiceAuth.JTICache.ETS, ttl_check_interval: :timer.seconds(10)
  ```
  """

  @behaviour Atex.ServiceAuth.JTICache
  use Supervisor

  @cache :atex_service_auth_jti_cache
  @default_ttl_check_interval :timer.seconds(30)

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    ttl_check_interval =
      Application.get_env(:atex, __MODULE__, [])
      |> Keyword.get(:ttl_check_interval, @default_ttl_check_interval)

    children = [
      {ConCache,
       [
         name: @cache,
         ttl_check_interval: ttl_check_interval,
         # No global TTL - each entry sets its own based on token expiry.
         global_ttl: :infinity
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @impl Atex.ServiceAuth.JTICache
  @spec put(String.t(), integer()) :: :ok | :seen
  def put(jti, expires_at) do
    now_unix = System.os_time(:second)
    remaining_ms = max((expires_at - now_unix) * 1_000, 0)

    result =
      ConCache.insert_new(@cache, jti, %ConCache.Item{
        value: true,
        ttl: remaining_ms
      })

    case result do
      :ok -> :ok
      {:error, :already_exists} -> :seen
    end
  end

  @impl Atex.ServiceAuth.JTICache
  @spec get(String.t()) :: :ok | :seen
  def get(jti) do
    case ConCache.get(@cache, jti) do
      nil -> :ok
      _ -> :seen
    end
  end
end
