defmodule Atex.HTTP.Adapter do
  @moduledoc """
  Behaviour for defining a HTTP client adapter to be used within atex.
  """
  alias Atex.HTTP.Response

  @type success() :: {:ok, Response.t()}
  @type error() :: {:error, Response.t() | term()}
  @type result() :: success() | error()

  @callback get(url :: String.t(), opts :: keyword()) :: result()
  @callback post(url :: String.t(), opts :: keyword()) :: result()
end
