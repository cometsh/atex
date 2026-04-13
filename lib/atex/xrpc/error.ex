defmodule Atex.XRPC.Error do
  @moduledoc """
  Represents an XRPC error response.

  When a lexicon defines errors for a query or procedure, the XRPC client will
  attempt to coerce error responses into typed error structs. If the error
  matches a known lexicon error, `error_struct` will contain the specific struct.
  If the error is unknown, `error_struct` will be `nil`.

  ## XRPC Error Response Format

  Per the XRPC spec, error responses have the following JSON structure:

  ```json
  {
    "error": "ErrorName",
    "message": "Human-readable description"
  }
  ```

  ## Examples

      %Atex.XRPC.Error{error: "SomethingBroke", message: "Database connection failed"}

      # With a typed error struct
      %Atex.XRPC.Error{
        error: "SomethingBroke",
        message: "Database connection failed",
        error_struct: %Com.Example.DoThing.Errors.SomethingBroke{message: "Database connection failed"}
      }
  """

  @enforce_keys [:error]
  defstruct [:error, :message, :error_struct]

  @type t :: %__MODULE__{
          error: String.t(),
          message: String.t() | nil,
          error_struct: module() | nil
        }
end
