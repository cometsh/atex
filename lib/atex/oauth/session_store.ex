defmodule Atex.OAuth.SessionStore do
  @moduledoc """
  Storage interface for OAuth sessions.

  Provides a behaviour for implementing session storage backends, and functions
  to operate the backend using `Atex.OAuth.Session`

  ## Configuration

  The default implementation for the store is `Atex.OAuth.SessionStore.DETS`;
  this can be changed to a custom implementation in your config.exs:

      config :atex, :session_store, Atex.OAuth.SessionStore.ETS

  DETS is the default implementation as it provides simple, on-disk storage for
  sessions so they don't get discarded on an application restart, but a regular
  ETS implementation is also provided out-of-the-box for testing or other
  circumstances.

  For multi-node deployments, you can write your own implementation using a
  custom backend, such as Redis, by implementing the behaviour callbacks.

  ## Usage

  Sessions are keyed by the user's DID (`sub` field).

      session = %Atex.OAuth.Session{
        iss: "https://bsky.social",
        aud: "https://puffball.us-east.host.bsky.network",
        sub: "did:plc:abc123",
        access_token: "...",
        refresh_token: "...",
        expires_at: ~N[2026-01-04 12:00:00],
        dpop_key: dpop_key,
        dpop_nonce: "server-nonce"
      }

      # Insert a new session
      :ok = Atex.OAuth.SessionStore.insert(session)

      # Retrieve a session
      {:ok, session} = Atex.OAuth.SessionStore.get("did:plc:abc123")

      # Update an existing session (e.g., after token refresh)
      updated_session = %{session | access_token: new_token}
      :ok = Atex.OAuth.SessionStore.update(updated_session)

      # Delete a session
      Atex.OAuth.SessionStore.delete(session)
  """

  @store Application.compile_env(:atex, :session_store, Atex.OAuth.SessionStore.DETS)

  @doc """
  Retrieve a session by DID.

  Returns `{:ok, session}` if found, `{:error, :not_found}` otherwise.
  """
  @callback get(key :: String.t()) :: {:ok, Atex.OAuth.Session.t()} | {:error, atom()}

  @doc """
  Insert a new session.

  The key is the user's DID (`session.sub`). Returns `:ok` on success.
  """
  @callback insert(key :: String.t(), session :: Atex.OAuth.Session.t()) ::
              :ok | {:error, atom()}

  @doc """
  Update an existing session.

  Replaces the existing session data for the given key. Returns `:ok` on success.
  """
  @callback update(key :: String.t(), session :: Atex.OAuth.Session.t()) ::
              :ok | {:error, atom()}

  @doc """
  Delete a session.

  Returns `:ok` if deleted, `:noop` if the session didn't exist, :error if it failed.
  """
  @callback delete(key :: String.t()) :: :ok | :error | :noop

  @callback child_spec(any()) :: Supervisor.child_spec()

  defdelegate child_spec(opts), to: @store

  @doc """
  Retrieve a session by DID.
  """
  @spec get(String.t()) :: {:ok, Atex.OAuth.Session.t()} | {:error, atom()}
  def get(key) do
    @store.get(key)
  end

  @doc """
  Insert a new session.
  """
  @spec insert(Atex.OAuth.Session.t()) :: :ok | {:error, atom()}
  def insert(session) do
    @store.insert(session.sub, session)
  end

  @doc """
  Update an existing session.
  """
  @spec update(Atex.OAuth.Session.t()) :: :ok | {:error, atom()}
  def update(session) do
    @store.update(session.sub, session)
  end

  @doc """
  Delete a session.
  """
  @callback delete(Atex.OAuth.Session.t()) :: :ok | :error | :noop
  def delete(session) do
    @store.delete(session.sub)
  end
end
