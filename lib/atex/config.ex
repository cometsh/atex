defmodule Atex.Config do
  @moduledoc """
  Library-wide configuration for `Atex`.

  ## Configuration

  The following keys are supported under `config :atex`:

      config :atex,
        plc_directory_url: "https://plc.directory",
        service_did: "did:web:my-service.example",
        user_agent: "my-app/1.0.0"

  - `:plc_directory_url` - Base URL for the did:plc directory server.
    Defaults to `"https://plc.directory"`.
  - `:service_did` - The DID of this service, used as the expected `aud` claim
    when validating incoming inter-service auth JWTs via `Atex.XRPC.Router`.
    Required when using `Atex.XRPC.Router` with auth enabled.
  - `:user_agent` - Custom User-Agent prefix for outgoing XRPC requests. When
    set, the `User-Agent` header becomes `"<user_agent> (atex/<version>)"`.
    Defaults to `"atex/<version>"`.
  """

  @doc """
  Returns the configured base URL for the did:plc directory server.

  Reads `:plc_directory_url` from the `:atex` application environment.
  Defaults to `"https://plc.directory"`.
  """
  @spec directory_url :: String.t()
  def directory_url,
    do: Application.get_env(:atex, :plc_directory_url, "https://plc.directory")

  @doc """
  Returns the configured service DID to be used for validation service auth tokens.

  Reads `:service_did` from the `:atex application environment.
  """
  @spec service_did :: String.t() | nil
  def service_did, do: Application.get_env(:atex, :service_did)

  @doc """
  Returns the `User-Agent` header value for outgoing XRPC requests.

  Reads `:user_agent` from the `:atex` application environment. When set, the
  atex library version is appended in parentheses. When unset, returns only
  the atex version.

  ## Examples

      # Default (no :user_agent configured):
      # => "atex/<version>"

      # With `config :atex, user_agent: "my-app/1.0.0"`:
      # => "my-app/1.0.0 (atex/<version>)"

  """
  @spec user_agent :: String.t()
  def user_agent do
    version = to_string(Application.spec(:atex, :vsn))
    atex_ua = "atex/#{version}"

    case Application.get_env(:atex, :user_agent) do
      nil -> atex_ua
      custom -> "#{custom} (#{atex_ua})"
    end
  end
end
