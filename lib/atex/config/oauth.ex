defmodule Atex.Config.OAuth do
  @moduledoc """
  Configuration management for `Atex.OAuth`.

  Contains all the logic for fetching configuration needed for the OAuth
  module, as well as deriving useful values from them.

  ## Configuration

  The following structure is expected in your application config:

      config :atex, Atex.OAuth,
        base_url: "https://example.com/oauth",  # Your application's base URL, including the path `Atex.OAuth` is mounted on.
        private_key: "base64-encoded-private-key",  # ES256 private key
        key_id: "your-key-id",  # Key identifier for JWTs
        scopes: ["transition:generic", "transition:email"],  # Optional additional scopes
        extra_redirect_uris: ["https://alternative.com/callback"],  # Optional additional redirect URIs
        is_localhost: false  # Set to true for local development
  """

  @doc """
  Returns the configured public base URL for OAuth routes.
  """
  @spec base_url() :: String.t()
  def base_url, do: Application.fetch_env!(:atex, Atex.OAuth)[:base_url]

  @doc """
  Returns the configured private key as a `JOSE.JWK`.
  """
  @spec get_key() :: JOSE.JWK.t()
  def get_key() do
    private_key =
      Application.fetch_env!(:atex, Atex.OAuth)[:private_key]
      |> Base.decode64!()
      |> JOSE.JWK.from_der()

    key_id = Application.fetch_env!(:atex, Atex.OAuth)[:key_id]

    %{private_key | fields: %{"kid" => key_id}}
  end

  @doc """
  Returns the client ID based on configuration.

  If `is_localhost` is set, it'll be a string handling the "http://localhost"
  special case, with the redirect URI and scopes configured, otherwise it is a
  string pointing to the location of the `client-metadata.json` route.
  """
  @spec client_id() :: String.t()
  def client_id() do
    is_localhost = Keyword.get(Application.get_env(:atex, Atex.OAuth, []), :is_localhost, false)

    if is_localhost do
      query =
        %{redirect_uri: redirect_uri(), scope: scopes()}
        |> URI.encode_query()

      "http://localhost?#{query}"
    else
      "#{base_url()}/client-metadata.json"
    end
  end

  @doc """
  Returns the configured redirect URI.
  """
  @spec redirect_uri() :: String.t()
  def redirect_uri(), do: "#{base_url()}/callback"

  @doc """
  Returns the configured scopes joined as a space-separated string.
  """
  @spec scopes() :: String.t()
  def scopes() do
    config_scopes = Keyword.get(Application.get_env(:atex, Atex.OAuth, []), :scopes, [])
    Enum.join(["atproto" | config_scopes], " ")
  end

  @doc """
  Returns the configured extra redirect URIs.
  """
  @spec extra_redirect_uris() :: [String.t()]
  def extra_redirect_uris() do
    Keyword.get(Application.get_env(:atex, Atex.OAuth, []), :extra_redirect_uris, [])
  end
end
