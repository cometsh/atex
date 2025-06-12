defmodule Atex.HTTP do
  @adapter Application.compile_env(:atex, :adapter, Atex.HTTP.Adapter.Req)

  defdelegate get(url, opts), to: @adapter
  defdelegate post(url, opts), to: @adapter
end
