defmodule Atex.XRPC.Adapter do
  @moduledoc """
  Behaviour for defining a HTTP client adapter to be used for XRPC.
  """

  @type success() :: {:ok, map()}
  @type error() :: {:error, integer(), map()} | {:error, term()}
  @type result() :: success() | error()

  @callback get(url :: String.t(), opts :: keyword()) :: result()
  @callback post(url :: String.t(), opts :: keyword()) :: result()
end
