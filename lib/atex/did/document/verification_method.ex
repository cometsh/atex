defmodule Atex.DID.Document.VerificationMethod do
  @moduledoc """
  Struct and schema for a `verificationMethod` entry in a DID document.

  Internally, public keys are always stored as `JOSE.JWK` structs regardless of the
  wire encoding.  Both the current `Multikey` format and the legacy
  `EcdsaSecp256r1VerificationKey2019` / `EcdsaSecp256k1VerificationKey2019` formats
  are accepted during parsing.

  ## Wire formats

  **Current (`Multikey`)**

  ```json
  {
    "id": "did:plc:abc123#atproto",
    "type": "Multikey",
    "controller": "did:plc:abc123",
    "publicKeyMultibase": "zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo"
  }
  ```

  **Legacy (uncompressed multibase, curve identified by `type`)**

  ```json
  {
    "id": "#atproto",
    "type": "EcdsaSecp256k1VerificationKey2019",
    "controller": "did:plc:abc123",
    "publicKeyMultibase": "zQYEBzXeuTM9UR3rfvNag6L3RNAs5pQZyYPsomTsgQhsxLdEgCrPTLgFna8yqCnxPpNT7DBk6Ym3dgPKNu86vt9GR"
  }
  ```

  ## Fields

  - `:id` - URI identifying the key, typically a DID fragment (e.g. `"#atproto"`).
  - `:type` - Key type string (e.g. `"Multikey"`).
  - `:controller` - DID of the entity that controls this key.
  - `:public_key_jwk` - The public key as a `JOSE.JWK` struct, or `nil` if the wire
    format could not be decoded.
  """
  import Peri
  use TypedStruct

  @legacy_types ~w(EcdsaSecp256r1VerificationKey2019 EcdsaSecp256k1VerificationKey2019)

  defschema :schema, %{
    id: {:required, Atex.Peri.uri()},
    type: {:required, :string},
    controller: {:required, Atex.Peri.did()},
    public_key_multibase: :string
  }

  typedstruct do
    field :id, String.t(), enforce: true
    field :type, String.t(), enforce: true
    field :controller, String.t(), enforce: true
    field :public_key_jwk, JOSE.JWK.t() | nil
  end

  @doc """
  Validates and builds a `VerificationMethod` struct from a raw map.

  Accepts camelCase or snake_case keys.  The public key in `publicKeyMultibase` - whether
  in the current `Multikey` format or the legacy uncompressed format - is decoded and stored
  as `public_key_jwk`.

  Returns `{:ok, t()}` on success, or `{:error, term()}` on validation or decode failure.

  ## Examples

      iex> Atex.DID.Document.VerificationMethod.new(%{
      ...>   "id" => "did:plc:abc123#atproto",
      ...>   "type" => "Multikey",
      ...>   "controller" => "did:plc:abc123",
      ...>   "publicKeyMultibase" => "zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo"
      ...> })
      {:ok, %Atex.DID.Document.VerificationMethod{
        id: "did:plc:abc123#atproto",
        type: "Multikey",
        controller: "did:plc:abc123",
        public_key_jwk: %JOSE.JWK{}
      }}
  """
  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(%{} = map) do
    snake = Recase.Enumerable.convert_keys(map, &Recase.to_snake/1)

    with {:ok, params} <- schema(snake) do
      jwk = resolve_public_key(params)
      {:ok, struct(__MODULE__, Map.put(params, :public_key_jwk, jwk))}
    end
  end

  @doc """
  Converts a `VerificationMethod` struct to a camelCase map for JSON serialisation.

  The public key is always emitted in the canonical `Multikey` / `publicKeyMultibase`
  format.  If no public key is present, `"publicKeyMultibase"` is omitted.

  ## Examples

      iex> {:ok, vm} = Atex.DID.Document.VerificationMethod.new(%{
      ...>   "id" => "did:plc:abc123#atproto",
      ...>   "type" => "Multikey",
      ...>   "controller" => "did:plc:abc123",
      ...>   "publicKeyMultibase" => "zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo"
      ...> })
      iex> json = Atex.DID.Document.VerificationMethod.to_json(vm)
      iex> json["type"]
      "Multikey"
      iex> is_binary(json["publicKeyMultibase"])
      true
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = vm) do
    base = %{
      "id" => vm.id,
      "type" => "Multikey",
      "controller" => vm.controller
    }

    case vm.public_key_jwk && Atex.Crypto.encode_did_key(vm.public_key_jwk) do
      {:ok, multibase} -> Map.put(base, "publicKeyMultibase", multibase)
      _ -> base
    end
  end

  # Resolve the public key from validated (snake_case) params to a JOSE.JWK or nil.
  @spec resolve_public_key(map()) :: JOSE.JWK.t() | nil
  defp resolve_public_key(%{type: type, public_key_multibase: multibase})
       when type in @legacy_types and is_binary(multibase) do
    case Atex.Crypto.decode_legacy_multibase(type, multibase) do
      {:ok, jwk} -> jwk
      _ -> nil
    end
  end

  defp resolve_public_key(%{public_key_multibase: multibase}) when is_binary(multibase) do
    case Atex.Crypto.decode_did_key(multibase) do
      {:ok, jwk} -> jwk
      _ -> nil
    end
  end

  defp resolve_public_key(_), do: nil
end

defimpl JSON.Encoder, for: Atex.DID.Document.VerificationMethod do
  def encode(value, encoder),
    do: JSON.encode!(Atex.DID.Document.VerificationMethod.to_json(value), encoder)
end
