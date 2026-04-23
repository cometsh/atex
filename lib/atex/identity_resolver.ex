defmodule Atex.IdentityResolver do
  @moduledoc """
  Resolves AT Protocol identifiers (DIDs and handles) to `Atex.IdentityResolver.Identity` structs.

  Resolution results are cached in `Atex.IdentityResolver.Cache` (ETS) to avoid
  repeated network calls. Handle resolution strategy is compile-time configurable:

      config :atex, handle_resolver_strategy: :dns_first  # default: :dns_first

  ## Examples

      {:ok, identity} = Atex.IdentityResolver.resolve("user.bsky.social")
      {:ok, identity} = Atex.IdentityResolver.resolve("did:plc:abc123")

  """

  alias Atex.IdentityResolver.{Cache, DID, Handle, Identity}
  alias Atex.DID.Document, as: DIDDocument

  @handle_strategy Application.compile_env(:atex, :handle_resolver_strategy, :dns_first)
  @type options() :: {:skip_cache, boolean()}

  # TODO: simplify errors

  @doc """
  Resolve a DID or handle to an `Atex.IdentityResolver.Identity` struct.

  For a DID, resolves the DID document and optionally cross-checks the handle
  declared in it. For a handle, resolves to a DID via DNS or HTTP, then fetches
  and validates the DID document.

  Results are cached. Pass `skip_cache: true` to force a fresh resolution.

  ## Parameters

  - `identifier` - A DID string (e.g., `"did:plc:abc123"`) or a handle (e.g., `"user.bsky.social"`)
  - `opts` - Keyword options:
    - `:skip_cache` - If `true`, bypass the cache (default: `false`)

  ## Returns

  - `{:ok, identity}` - Successfully resolved identity
  - `{:error, :handle_mismatch}` - Handle in DID document does not match resolved handle
  - `{:error, reason}` - Resolution or network failure
  """
  @spec resolve(String.t(), list(options())) :: {:ok, Identity.t()} | {:error, any()}
  def resolve(identifier, opts \\ []) do
    opts = Keyword.validate!(opts, skip_cache: false)
    skip_cache = Keyword.get(opts, :skip_cache)
    identifier_type = if String.starts_with?(identifier, "did:"), do: :did, else: :handle

    Atex.Telemetry.span(
      [:atex, :identity_resolver, :resolve],
      %{identifier: identifier, identifier_type: identifier_type},
      fn ->
        cache_result = if skip_cache, do: {:error, :not_found}, else: Cache.get(identifier)

        cache_event = if match?({:ok, _}, cache_result), do: :hit, else: :miss

        Atex.Telemetry.execute(
          [:atex, :identity_resolver, :cache, cache_event],
          %{system_time: System.system_time()},
          %{identifier: identifier}
        )

        # If cache fetch succeeds, then the ok tuple will be retuned by the default `with` behaviour
        result =
          with {:error, :not_found} <- cache_result,
               {:ok, identity} <- do_resolve(identifier),
               identity <- Cache.insert(identity) do
            {:ok, identity}
          end

        {result, %{}}
      end
    )
  end

  @spec do_resolve(identity :: String.t()) ::
          {:ok, Identity.t()}
          | {:error, :handle_mismatch}
          | {:error, any()}
  defp do_resolve("did:" <> _ = did) do
    with {:ok, document} <- DID.resolve(did),
         :ok <- DIDDocument.validate_for_atproto(document, did) do
      with handle when not is_nil(handle) <- DIDDocument.get_atproto_handle(document),
           {:ok, handle_did} <- Handle.resolve(handle, @handle_strategy),
           true <- handle_did == did do
        {:ok, Identity.new(did, handle, document)}
      else
        # Not having a handle, while a little un-ergonomic, is totally valid.
        nil -> {:ok, Identity.new(did, nil, document)}
        false -> {:error, :handle_mismatch}
        e -> e
      end
    end
  end

  defp do_resolve(handle) do
    with {:ok, did} <- Handle.resolve(handle, @handle_strategy),
         {:ok, document} <- DID.resolve(did),
         did_handle when not is_nil(handle) <- DIDDocument.get_atproto_handle(document),
         true <- did_handle == handle do
      {:ok, Identity.new(did, handle, document)}
    else
      nil -> {:error, :handle_mismatch}
      false -> {:error, :handle_mismatch}
      e -> e
    end
  end
end
