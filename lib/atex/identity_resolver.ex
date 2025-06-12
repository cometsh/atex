defmodule Atex.IdentityResolver do
  alias Atex.IdentityResolver.{DID, DIDDocument, Handle}

  @handle_strategy Application.compile_env(:atex, :handle_resolver_strategy, :dns_first)

  # TODO: simplify errors

  @spec resolve(identity :: String.t()) ::
          {:ok, document :: DIDDocument.t(), did :: String.t(), handle :: String.t()}
          | {:ok, DIDDocument.t()}
          | {:error, :handle_mismatch}
          | {:error, any()}
  def resolve("did:" <> _ = did) do
    with {:ok, document} <- DID.resolve(did),
         :ok <- DIDDocument.validate_for_atproto(document, did) do
      with handle when not is_nil(handle) <- DIDDocument.get_atproto_handle(document),
           {:ok, handle_did} <- Handle.resolve(handle, @handle_strategy),
           true <- handle_did == did do
        {:ok, document, did, handle}
      else
        # Not having a handle, while a little un-ergonomic, is totally valid.
        nil -> {:ok, document}
        false -> {:error, :handle_mismatch}
        e -> e
      end
    end
  end

  def resolve(handle) do
    with {:ok, did} <- Handle.resolve(handle, @handle_strategy),
         {:ok, document} <- DID.resolve(did),
         did_handle when not is_nil(handle) <- DIDDocument.get_atproto_handle(document),
         true <- did_handle == handle do
      {:ok, document, did, handle}
    else
      nil -> {:error, :handle_mismatch}
      false -> {:error, :handle_mismatch}
      e -> e
    end
  end
end
