defmodule Atex.Config do
  @moduledoc """
  Library-wide configuration for `Atex`.

  ## Configuration

  The following keys are supported under `config :atex`:

      config :atex,
        plc_directory_url: "https://plc.directory"

  - `:plc_directory_url` - Base URL for the did:plc directory server.
    Defaults to `"https://plc.directory"`.
  """

  @doc """
  Returns the configured base URL for the did:plc directory server.

  Reads `:plc_directory_url` from the `:atex` application environment.
  Defaults to `"https://plc.directory"`.
  """
  @spec directory_url :: String.t()
  def directory_url,
    do: Application.get_env(:atex, :plc_directory_url, "https://plc.directory")
end
