defmodule Atex.Config.IdentityResolver do
  @moduledoc """
  Configuration management for `Atex.IdentityResolver`.

  Contains all configuration logic for fetching identity documents.

  ## Configuration

  The following structure is expected in your application config:

      config :atex, Atex.IdentityResolver,
        directory_url: "https://plc.directory" # An address to a did:plc document host
  """

  @doc """
  Returns the configured URL for PLC queries.
  """
  @spec directory_url :: String.t()
  def directory_url(),
    do:
      Keyword.get(
        Application.get_env(:atex, Atex.IdentityResolver, []),
        :directory_url,
        "https://plc.directory"
      )
end
