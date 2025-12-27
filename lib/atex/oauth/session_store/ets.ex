defmodule Atex.OAuth.SessionStore.ETS do
  @moduledoc """
  In-memory, ETS implementation for `Atex.OAuth.SessionStore`.

  This is moreso intended for testing or some occasion where you want the
  session store to be volatile for some reason. It's recommended you use
  `Atex.OAuth.SessionStore.DETS` for single-node production deployments.
  """

  alias Atex.OAuth.Session
  require Logger
  use Supervisor

  @behaviour Atex.OAuth.SessionStore
  @table :atex_oauth_sessions

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table])
    Supervisor.init([], strategy: :one_for_one)
  end

  @doc """
  Insert a session into the ETS table.

  Returns `:ok` on success, `{:error, :ets}` if an unexpected error occurs.
  """
  @impl Atex.OAuth.SessionStore
  @spec insert(String.t(), Session.t()) :: :ok | {:error, atom()}
  def insert(key, session) do
    try do
      :ets.insert(@table, {key, session})
      :ok
    rescue
      # Freak accidents can occur
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        {:error, :ets}
    end
  end

  @doc """
  Update a session in the ETS table.

  In ETS, this is the same as insert - it replaces the existing entry.
  """
  @impl Atex.OAuth.SessionStore
  @spec update(String.t(), Session.t()) :: :ok | {:error, atom()}
  def update(key, session) do
    insert(key, session)
  end

  @doc """
  Retrieve a session from the ETS table.

  Returns `{:ok, session}` if found, `{:error, :not_found}` otherwise.
  """
  @impl Atex.OAuth.SessionStore
  @spec get(String.t()) :: {:ok, Session.t()} | {:error, atom()}
  def get(key) do
    case :ets.lookup(@table, key) do
      [{_key, session}] -> {:ok, session}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Delete a session from the ETS table.

  Returns `:ok` if deleted, `:noop` if the session didn't exist.
  """
  @impl Atex.OAuth.SessionStore
  @spec delete(String.t()) :: :ok | :error | :noop
  def delete(key) do
    case get(key) do
      {:ok, _session} ->
        :ets.delete(@table, key)
        :ok

      {:error, :not_found} ->
        :noop
    end
  end
end
