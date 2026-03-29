defmodule Atex.Lexicon.Resolver do
  @moduledoc """
  Resolves published AT Protocol Lexicon schemas by NSID.

  Implements the [Lexicon publication and resolution](https://atproto.com/specs/lexicon#lexicon-publication-and-resolution)
  specification, which uses DNS TXT records to locate the atproto repository
  that hosts a given NSID's schema, then fetches the record directly from
  the repository's PDS.

  Per the specification, DNS resolution is not hierarchical: if the TXT
  record for the exact authority domain is not found, resolution fails
  immediately without traversing the DNS hierarchy.

  ## Error returns

  `resolve/1` returns `{:error, reason}` on failure. Possible reasons:

  - `:invalid_nsid` - the given string is not a valid NSID.
  - `:dns_resolution_failed` - no valid `did=<did>` TXT record was found for
    the authority domain.
  - `:did_resolution_failed` - the DID from DNS could not be resolved to a
    DID document.
  - `:no_pds_endpoint` - the DID document does not contain a valid PDS service
    endpoint.
  - `:record_not_found` - the PDS has no lexicon record for the given NSID.
  - `:invalid_record` - the PDS returned a response that could not be
    interpreted as a lexicon record.
  - Any transport-level error from `Req`.
  """

  alias Atex.{DID, NSID, Util, XRPC}
  alias Atex.IdentityResolver.DID, as: DIDResolver

  @collection "com.atproto.lexicon.schema"

  @doc """
  Resolves the lexicon schema for the given NSID.

  Performs DNS-based authority lookup followed by an atproto record fetch to
  retrieve the raw lexicon JSON map.

  ## Parameters

  - `nsid` - A valid AT Protocol NSID string.

  ## Examples

      iex> Atex.Lexicon.Resolver.resolve("app.bsky.feed.post")
      {:ok, %{"lexicon" => 1, "id" => "app.bsky.feed.post", "defs" => %{...}}}

      iex> Atex.Lexicon.Resolver.resolve("not.valid!")
      {:error, :invalid_nsid}
  """
  @spec resolve(String.t()) ::
          {:ok, map()}
          | {:error,
             :invalid_nsid
             | :dns_resolution_failed
             | :did_resolution_failed
             | :no_pds_endpoint
             | :record_not_found
             | :invalid_record
             | any()}
  def resolve(nsid) do
    with {:ok, authority_domain} <- NSID.authority_domain(nsid),
         {:ok, did} <- resolve_did_from_dns(authority_domain),
         {:ok, document} <- resolve_did_document(did),
         {:ok, pds_endpoint} <- get_pds_endpoint(document) do
      fetch_record(pds_endpoint, did, nsid)
    end
  end

  @spec resolve_did_from_dns(String.t()) :: {:ok, String.t()} | {:error, :dns_resolution_failed}
  defp resolve_did_from_dns(authority_domain) do
    authority_domain
    |> Util.query_dns(:txt)
    |> Enum.find_value(fn
      "did=" <> did -> if DID.match?(did), do: did
      _ -> nil
    end)
    |> case do
      nil -> {:error, :dns_resolution_failed}
      did -> {:ok, did}
    end
  end

  @spec resolve_did_document(String.t()) ::
          {:ok, DID.Document.t()} | {:error, :did_resolution_failed}
  defp resolve_did_document(did) do
    case DIDResolver.resolve(did) do
      {:ok, document} -> {:ok, document}
      _ -> {:error, :did_resolution_failed}
    end
  end

  @spec get_pds_endpoint(DID.Document.t()) ::
          {:ok, String.t()} | {:error, :no_pds_endpoint}
  defp get_pds_endpoint(document) do
    case DID.Document.get_pds_endpoint(document) do
      nil -> {:error, :no_pds_endpoint}
      endpoint -> {:ok, endpoint}
    end
  end

  @spec fetch_record(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, :record_not_found | :invalid_record | any()}
  defp fetch_record(pds_endpoint, did, nsid) do
    client = XRPC.UnauthedClient.new(pds_endpoint)

    case XRPC.get(client, "com.atproto.repo.getRecord",
           params: [repo: did, collection: @collection, rkey: nsid]
         ) do
      {:ok, %{status: 200, body: body}, _} -> parse_record_body(body)
      {:ok, %{status: 404}} -> {:error, :record_not_found}
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec parse_record_body(map() | binary()) ::
          {:ok, map()} | {:error, :invalid_record}
  defp parse_record_body(body) when is_map(body) do
    case Map.fetch(body, "value") do
      {:ok, value} when is_map(value) -> {:ok, value}
      _ -> {:error, :invalid_record}
    end
  end

  defp parse_record_body(body) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, map} -> parse_record_body(map)
      _ -> {:error, :invalid_record}
    end
  end

  defp parse_record_body(_), do: {:error, :invalid_record}
end
