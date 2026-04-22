defmodule Atex.OAuth do
  @moduledoc """
  AT Protocol OAuth 2.0 session management.

  Provides Plug session helpers for managing OAuth sessions in a web application.
  For the full OAuth flow, see `Atex.OAuth.Flow`. For authorization server
  discovery, see `Atex.OAuth.Discovery`. For DPoP token handling, see
  `Atex.OAuth.DPoP`.

  ## Type re-exports

  The following types are re-exported here for backward compatibility:

  - `t:Atex.OAuth.Flow.authorization_metadata/0`
  - `t:Atex.OAuth.Flow.tokens/0`
  """

  alias Atex.OAuth.SessionStore

  @type authorization_metadata() :: Atex.OAuth.Flow.authorization_metadata()
  @type tokens() :: Atex.OAuth.Flow.tokens()

  @session_keys_name :atex_sessions
  @session_active_name :atex_active_session

  @doc """
  Return the session key atom used to store the list of session keys in a
  `Plug.Conn` session.

  Used by `Atex.OAuth.Plug` when reading and writing session data.
  """
  @spec session_keys_name() :: atom()
  def session_keys_name, do: @session_keys_name

  @doc """
  Return the session key atom used to store the active session key in a
  `Plug.Conn` session.

  Used by `Atex.OAuth.Plug` when reading and writing session data.
  """
  @spec session_active_session_name() :: atom()
  def session_active_session_name, do: @session_active_name

  @doc """
  Generate a random base64url-encoded nonce suitable for use in OAuth flows.

  Returns a 32-byte random value encoded as a URL-safe base64 string without
  padding. Useful when building custom authorization flows.

  ## Examples

      iex> nonce = Atex.OAuth.create_nonce()
      iex> is_binary(nonce)
      true
  """
  @spec create_nonce() :: String.t()
  def create_nonce do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @doc """
  Get the key of the currently active OAuth session from the connection.

  Returns `nil` if no session is currently active.

  ## Parameters

  - `conn` - A `Plug.Conn` with session data loaded
  """
  @spec current_session_key(Plug.Conn.t()) :: String.t() | nil
  def current_session_key(conn) do
    Plug.Conn.get_session(conn, @session_active_name)
  end

  @doc """
  List all OAuth session keys stored in the connection's session.

  ## Parameters

  - `conn` - A `Plug.Conn` with session data loaded
  """
  @spec list_session_keys(Plug.Conn.t()) :: list(String.t())
  def list_session_keys(conn) do
    Plug.Conn.get_session(conn, @session_keys_name) || []
  end

  @doc """
  Switch the active OAuth session to the given key.

  Updates the `:atex_active_session` value in the Plug session.

  ## Parameters

  - `conn` - A `Plug.Conn` with session data loaded
  - `session_key` - The session key to make active
  """
  @spec switch_session(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def switch_session(conn, session_key) do
    Plug.Conn.put_session(conn, @session_active_name, session_key)
  end

  @doc """
  Delete the currently active OAuth session.

  Removes the active session from `SessionStore`, removes its key from the
  session key list, and clears the active session pointer in the Plug session.

  ## Parameters

  - `conn` - A `Plug.Conn` with session data loaded
  """
  @spec delete_session(Plug.Conn.t()) :: Plug.Conn.t()
  def delete_session(conn) do
    session_key = current_session_key(conn)

    if session_key do
      SessionStore.delete(session_key)
    end

    session_keys = list_session_keys(conn) |> List.delete(session_key)

    conn
    |> Plug.Conn.put_session(@session_keys_name, session_keys)
    |> Plug.Conn.delete_session(@session_active_name)
  end
end
