defmodule Atex.HTTP.Adapter.Req do
  @moduledoc """
  `Req` adapter for atex.
  """

  @behaviour Atex.HTTP.Adapter

  @impl true
  def get(url, opts) do
    Req.get(url, opts) |> adapt()
  end

  @impl true
  def post(url, opts) do
    Req.post(url, opts) |> adapt()
  end

  @spec adapt({:ok, Req.Response.t()} | {:error, any()}) :: Atex.HTTP.Adapter.result()
  defp adapt({:ok, %Req.Response{status: status} = res}) when status < 400 do
    {:ok, to_response(res)}
  end

  defp adapt({:ok, %Req.Response{} = res}) do
    {:error, to_response(res)}
  end

  defp adapt({:error, exception}) do
    {:error, exception}
  end

  defp to_response(%Req.Response{} = res) do
    %Atex.HTTP.Response{
      body: res.body,
      status: res.status,
      __raw__: res
    }
  end
end
