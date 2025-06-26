defmodule Atex.IdentityResolver.Identity do
  use TypedStruct

  @typedoc """
  The controlling DID for an identity.
  """
  @type did() :: String.t()
  @typedoc """
  The human-readable handle for an identity. Can be missing.
  """
  @type handle() :: String.t() | nil
  @typedoc """
  The resolved DID document for an identity.
  """
  @type document() :: Atex.IdentityResolver.DIDDocument.t()

  typedstruct do
    field :did, did(), enforce: true
    field :handle, handle()
    field :document, document(), enforce: true
  end

  @spec new(did(), handle(), document()) :: t()
  def new(did, handle, document), do: %__MODULE__{did: did, handle: handle, document: document}
end
