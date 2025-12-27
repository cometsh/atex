defmodule Atex.OAuth.Error do
  @moduledoc """
  Exception raised by `Atex.OAuth.Plug` when errors occurred. When using the
  Plug, you should set up a `Plug.ErrorHandler` to gracefully catch these and
  give messages to the end user.

  This extesion has two fields: a human-readable `message` string, and an atom
  `reason` for each specific error.

  ## Reasons

  - `:missing_handle` - The handle query parameter was not provided
  - `:invalid_handle` - The provided handle could not be resolved
  - `:authorization_url_failed` - Failed to create the authorization URL
  - `:invalid_callback_request` - Missing or invalid state/code in callback
  - `:authorization_server_metadata_failed` - Could not fetch authorization
    server metadata
  - `:token_validation_failed` - Failed to validate the authorization code or
    token
  - `:issuer_mismatch` - OAuth issuer does not match PDS authorization server
  """

  defexception [:message, :reason]
end
