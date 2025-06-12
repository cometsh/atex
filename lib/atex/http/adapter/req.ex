defmodule Atex.HTTP.Adapter.Req do
  @moduledoc """
  `Req` adapter for atex.
  """

  @behaviour Atex.HTTP.Adapter

  def get(url, opts) do
    Req.get(url, opts) |> adapt()
  end

  def post(url, opts) do
    Req.post(url, opts) |> adapt()
  end

  defp adapt({:ok, %Req.Response{status: 200} = res}) do
    {:ok, res.body}
  end

  defp adapt({:ok, %Req.Response{} = res}) do
    {:error, res.status, res.body}
  end

  defp adapt({:error, exception}) do
    {:error, exception}
  end
end
