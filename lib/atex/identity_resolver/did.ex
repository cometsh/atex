defmodule Atex.IdentityResolver.DID do
  alias Atex.IdentityResolver.DIDDocument

  @type resolution_result() ::
          {:ok, DIDDocument.t()}
          | {:error, :invalid_did_type | :invalid_did | :not_found | map() | atom() | any()}

  @spec resolve(String.t()) :: resolution_result()
  def resolve("did:plc:" <> _ = did), do: resolve_plc(did)
  def resolve("did:web:" <> _ = did), do: resolve_web(did)
  def resolve("did:" <> _), do: {:error, :invalid_did_type}
  def resolve(_did), do: {:error, :invalid_did}

  @spec resolve_plc(String.t()) :: resolution_result()
  defp resolve_plc("did:plc:" <> _id = did) do
    with {:ok, resp} when resp.status in 200..299 <-
           Atex.HTTP.get("https://plc.directory/#{did}", []),
         {:ok, body} <- decode_body(resp.body),
         {:ok, document} <- DIDDocument.from_json(body),
         :ok <- DIDDocument.validate_for_atproto(document, did) do
      {:ok, document}
    else
      {:ok, %{status: status}} when status in [404, 410] -> {:error, :not_found}
      {:ok, %{} = resp} -> {:error, resp}
      e -> e
    end
  end

  @spec resolve_web(String.t()) :: resolution_result()
  defp resolve_web("did:web:" <> domain = did) do
    with {:ok, resp} when resp.status in 200..299 <-
           Atex.HTTP.get("https://#{domain}/.well-known/did.json", []),
         {:ok, body} <- decode_body(resp.body),
         {:ok, document} <- DIDDocument.from_json(body),
         :ok <- DIDDocument.validate_for_atproto(document, did) do
      {:ok, document}
    else
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{} = resp} -> {:error, resp}
      e -> e
    end
  end

  @spec decode_body(any()) ::
          {:ok, any()}
          | {:error, :invalid_body | JSON.decode_error_reason()}

  defp decode_body(body) when is_binary(body), do: JSON.decode(body)
  defp decode_body(body) when is_map(body), do: {:ok, body}
  defp decode_body(_body), do: {:error, :invalid_body}
end
