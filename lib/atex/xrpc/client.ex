defmodule Atex.XRPC.Client do
  @moduledoc """
  Behaviour that defines the interface for XRPC clients.

  This behaviour allows different types of clients (login-based, OAuth-based, etc.)
  to implement authentication and request handling while maintaining a consistent interface.

  Implementations must handle token refresh internally when requests fail due to
  expired tokens, and return both the result and potentially updated client state.
  """

  @type client :: struct()
  @type request_opts :: keyword()
  @type request_result :: {:ok, Req.Response.t(), client()} | {:error, any(), client()}

  @doc """
  Perform an authenticated HTTP GET request on an XRPC resource.

  Implementations should handle token refresh if the request fails due to
  expired authentication, returning both the response and the (potentially updated) client.
  """
  @callback get(client(), String.t(), request_opts()) :: request_result()

  @doc """
  Perform an authenticated HTTP POST request on an XRPC resource.

  Implementations should handle token refresh if the request fails due to
  expired authentication, returning both the response and the (potentially updated) client.
  """
  @callback post(client(), String.t(), request_opts()) :: request_result()
end
