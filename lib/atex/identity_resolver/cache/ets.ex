defmodule Atex.IdentityResolver.Cache.ETS do
  alias Atex.IdentityResolver.Identity
  @behaviour Atex.IdentityResolver.Cache
  use Supervisor

  @table :atex_identities

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table])
    Supervisor.init([], strategy: :one_for_one)
  end

  @impl Atex.IdentityResolver.Cache
  @spec insert(Identity.t()) :: Identity.t()
  def insert(identity) do
    # TODO: benchmark lookups vs match performance, is it better to use a "composite" key or two inserts?
    :ets.insert(@table, {{identity.did, identity.handle}, identity})
    identity
  end

  @impl Atex.IdentityResolver.Cache
  @spec get(String.t()) :: {:ok, Identity.t()} | {:error, atom()}
  def get(identifier) do
    lookup(identifier)
  end

  @impl Atex.IdentityResolver.Cache
  @spec delete(String.t()) :: :noop | Identity.t()
  def delete(identifier) do
    case lookup(identifier) do
      {:ok, identity} ->
        :ets.delete(@table, {identity.did, identity.handle})
        identity

      _ ->
        :noop
    end
  end

  defp lookup(identifier) do
    case :ets.match(@table, {{identifier, :_}, :"$1"}) do
      [] ->
        case :ets.match(@table, {{:_, identifier}, :"$1"}) do
          [] -> {:error, :not_found}
          [[identity]] -> {:ok, identity}
        end

      [[identity]] ->
        {:ok, identity}
    end
  end
end
