defmodule Atex.OAuth.SessionStore.DETS do
  @moduledoc """
  DETS implementation for `Atex.OAuth.SessionStore`.

  This is recommended for single-node production deployments, as sessions will
  persist on disk between application restarts. For more complex, multi-node
  deployments, consider making a custom implementation using Redis or some other
  distributed store.

  ## Configuration

  By default the DETS file is stored at `priv/dets/atex_oauth_sessions.dets`
  relative to where your application is running. You can configure the file path
  in your `config.exs`:

      config :atex, Atex.OAuth.SessionStore.DETS,
        file_path: "/var/lib/myapp/sessions.dets"

  Parent directories will be created as necessary if possible.
  """

  alias Atex.OAuth.Session
  require Logger
  use Supervisor

  @behaviour Atex.OAuth.SessionStore
  @table :atex_oauth_sessions
  @default_file "priv/dets/atex_oauth_sessions.dets"

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(_opts) do
    dets_file =
      case Application.get_env(:atex, __MODULE__, [])[:file_path] do
        nil ->
          @default_file

        path ->
          path
      end

    # Ensure parent directory exists
    dets_file
    |> Path.dirname()
    |> File.mkdir_p!()

    case :dets.open_file(@table, file: String.to_charlist(dets_file), type: :set) do
      {:ok, @table} ->
        Logger.info("DETS session store opened: #{dets_file}")
        Supervisor.init([], strategy: :one_for_one)

      {:error, reason} ->
        Logger.error("Failed to open DETS file: #{inspect(reason)}")
        raise "Failed to initialize DETS session store: #{inspect(reason)}"
    end
  end

  @doc """
  Insert a session into the DETS table.

  Returns `:ok` on success, `{:error, reason}` if an unexpected error occurs.
  """
  @impl Atex.OAuth.SessionStore
  @spec insert(String.t(), Session.t()) :: :ok | {:error, atom()}
  def insert(key, session) do
    case :dets.insert(@table, {key, session}) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("DETS insert failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Update a session in the DETS table.

  In DETS, this is the same as insert - it replaces the existing entry.
  """
  @impl Atex.OAuth.SessionStore
  @spec update(String.t(), Session.t()) :: :ok | {:error, atom()}
  def update(key, session) do
    insert(key, session)
  end

  @doc """
  Retrieve a session from the DETS table.

  Returns `{:ok, session}` if found, `{:error, :not_found}` otherwise.
  """
  @impl Atex.OAuth.SessionStore
  @spec get(String.t()) :: {:ok, Session.t()} | {:error, atom()}
  def get(key) do
    case :dets.lookup(@table, key) do
      [{_key, session}] -> {:ok, session}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Delete a session from the DETS table.

  Returns `:ok` if deleted, `:noop` if the session didn't exist.
  """
  @impl Atex.OAuth.SessionStore
  @spec delete(String.t()) :: :ok | :error | :noop
  def delete(key) do
    case get(key) do
      {:ok, _session} ->
        :dets.delete(@table, key)
        :ok

      {:error, :not_found} ->
        :noop
    end
  end
end
