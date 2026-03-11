defmodule Atex.Config do
  @moduledoc """
  Library-wide configuration for `Atex`.

  ## Configuration

  The following keys are supported under `config :atex`:

      config :atex,
        plc_directory_url: "https://plc.directory",
        service_did: "did:web:my-service.example"

  - `:plc_directory_url` - Base URL for the did:plc directory server.
    Defaults to `"https://plc.directory"`.
  - `:service_did` - The DID of this service, used as the expected `aud` claim
    when validating incoming inter-service auth JWTs via `Atex.XRPC.Router`.
    Required when using `Atex.XRPC.Router` with auth enabled.
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
end
