defmodule Atex.IdentityResolver.Handle do
  @type strategy() :: :dns_first | :http_first | :race | :both

  @spec resolve(String.t(), strategy()) ::
          {:ok, String.t()} | :error | {:error, :ambiguous_handle}
  def resolve(handle, strategy)

  def resolve(handle, :dns_first) do
    case resolve_via_dns(handle) do
      :error -> resolve_via_http(handle)
      ok -> ok
    end
  end

  def resolve(handle, :http_first) do
    case resolve_via_http(handle) do
      :error -> resolve_via_dns(handle)
      ok -> ok
    end
  end

  def resolve(handle, :race) do
    [&resolve_via_dns/1, &resolve_via_http/1]
    |> Task.async_stream(& &1.(handle), max_concurrency: 2, ordered: false)
    |> Stream.filter(&match?({:ok, {:ok, _}}, &1))
    |> Enum.at(0)
  end

  def resolve(handle, :both) do
    case Task.await_many([
           Task.async(fn -> resolve_via_dns(handle) end),
           Task.async(fn -> resolve_via_http(handle) end)
         ]) do
      [{:ok, dns_did}, {:ok, http_did}] ->
        if dns_did && http_did && dns_did != http_did do
          {:error, :ambiguous_handle}
        else
          {:ok, dns_did}
        end

      _ ->
        :error
    end
  end

  @spec resolve_via_dns(String.t()) :: {:ok, String.t()} | :error
  defp resolve_via_dns(handle) do
    with ["did=" <> did] <- query_dns("_atproto.#{handle}", :txt),
         "did:" <> _ <- did do
      {:ok, did}
    else
      _ -> :error
    end
  end

  @spec resolve_via_http(String.t()) :: {:ok, String.t()} | :error
  defp resolve_via_http(handle) do
    case Req.get("https://#{handle}/.well-known/atproto-did") do
      {:ok, %{body: "did:" <> _ = did}} -> {:ok, did}
      _ -> :error
    end
  end

  @spec query_dns(String.t(), :inet_res.dns_rr_type()) :: list(String.t() | list(String.t()))
  defp query_dns(domain, type) do
    domain
    |> String.to_charlist()
    |> :inet_res.lookup(:in, type)
    |> Enum.map(fn
      [result] -> to_string(result)
      result -> result
    end)
  end
end
