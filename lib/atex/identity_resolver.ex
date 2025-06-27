defmodule Atex.IdentityResolver do
  alias Atex.IdentityResolver.{Cache, DID, DIDDocument, Handle, Identity}

  @handle_strategy Application.compile_env(:atex, :handle_resolver_strategy, :dns_first)
  @type options() :: {:skip_cache, boolean()}

  # TODO: simplify errors

  @spec resolve(String.t(), list(options())) :: {:ok, Identity.t()} | {:error, any()}
  def resolve(identifier, opts \\ []) do
    opts = Keyword.validate!(opts, skip_cache: false)
    skip_cache = Keyword.get(opts, :skip_cache)

    cache_result = if skip_cache, do: {:error, :not_found}, else: Cache.get(identifier)

    # If cache fetch succeeds, then the ok tuple will be retuned by the default `with` behaviour
    with {:error, :not_found} <- cache_result,
         {:ok, identity} <- do_resolve(identifier),
         identity <- Cache.insert(identity) do
      {:ok, identity}
    end
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
