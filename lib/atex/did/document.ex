defmodule Atex.DID.Document do
  @moduledoc """
  Struct and schema for a [DID document](https://github.com/w3c/did-wg/blob/main/did-explainer.md#did-documents).

  Covers the subset of DID document fields used by AT Protocol, including support for
  parsing the `verificationMethod` and `service` arrays into typed sub-structs.

  ## Sub-structs

  - `Atex.DID.Document.VerificationMethod` - typed representation of a public key entry,
    with normalised `JOSE.JWK` storage regardless of wire encoding.
  - `Atex.DID.Document.Service` - typed representation of a service endpoint entry.

  ## Parsing

  Use `new/1` to parse a raw map (as returned by a DID resolution response).
  The function accepts camelCase keys as returned by the wire protocol, validates the
  document structure via Peri, and converts public keys into `JOSE.JWK` structs.

  ## Serialisation

  Use `to_json/1` to produce a camelCase map suitable for JSON encoding.  Public keys are
  always emitted in the canonical `Multikey` / `publicKeyMultibase` format, regardless of
  the format used when the document was originally parsed.

  ## ATProto-specific helpers

  - `validate_for_atproto/2` - checks the document meets minimum atproto requirements.
  - `get_atproto_handle/1` - extracts the claimed AT Protocol handle.
  - `get_pds_endpoint/1` - extracts the PDS service endpoint URL.
  - `get_atproto_signing_key/1` - extracts the atproto signing key as a `JOSE.JWK`.
  """
  import Peri
  use TypedStruct

  alias Atex.DID.Document.{Service, VerificationMethod}

  defschema :schema, %{
    "@context": {:required, {:list, Atex.Peri.uri()}},
    id: {:required, :string},
    controller: {:either, {Atex.Peri.did(), {:list, Atex.Peri.did()}}},
    also_known_as: {:list, Atex.Peri.uri()},
    verification_method: {:list, :map},
    authentication: {:list, {:either, {Atex.Peri.uri(), :map}}},
    service: {:list, :map}
  }

  typedstruct do
    field :"@context", list(String.t()), enforce: true
    field :id, String.t(), enforce: true
    field :controller, String.t() | list(String.t())
    field :also_known_as, list(String.t())
    field :verification_method, list(VerificationMethod.t())
    field :authentication, list(String.t() | VerificationMethod.t())
    field :service, list(Service.t())
  end

  @doc """
  Parses and validates a raw DID document map into a typed `t()` struct.

  Accepts the camelCase wire format as returned by DID resolution endpoints.
  `verificationMethod` and `service` entries are parsed into their respective sub-structs.
  Public keys are normalised to `JOSE.JWK` regardless of the wire encoding used.

  Returns `{:ok, t()}` on success, or `{:error, Peri.Error.t()}` on validation failure.

  ## Examples

      iex> Atex.DID.Document.new(%{
      ...>   "@context" => ["https://www.w3.org/ns/did/v1"],
      ...>   "id" => "did:plc:abc123",
      ...>   "verificationMethod" => [],
      ...>   "service" => []
      ...> })
      {:ok, %Atex.DID.Document{id: "did:plc:abc123", ...}}
  """
  @spec new(map()) :: {:ok, t()} | {:error, Peri.Error.t()}
  def new(%{} = map) do
    map
    |> Recase.Enumerable.convert_keys(&Recase.to_snake/1)
    |> schema()
    |> case do
      {:ok, params} ->
        verification_methods =
          params
          |> Map.get(:verification_method, [])
          |> Enum.map(&parse_verification_method/1)
          |> Enum.reject(&is_nil/1)

        services =
          params
          |> Map.get(:service, [])
          |> Enum.map(&parse_service/1)
          |> Enum.reject(&is_nil/1)

        authentication =
          params
          |> Map.get(:authentication, [])
          |> Enum.map(&parse_authentication_entry/1)
          |> Enum.reject(&is_nil/1)

        doc =
          struct(
            __MODULE__,
            params
            |> Map.put(:verification_method, verification_methods)
            |> Map.put(:service, services)
            |> Map.put(:authentication, authentication)
          )

        {:ok, doc}

      e ->
        e
    end
  end

  @doc """
  Serialises a `t()` struct to a camelCase map suitable for JSON encoding.

  Public keys in `verificationMethod` are always emitted in the canonical `Multikey`
  format with `publicKeyMultibase`.

  ## Examples

      iex> {:ok, doc} = Atex.DID.Document.new(%{
      ...>   "@context" => ["https://www.w3.org/ns/did/v1"],
      ...>   "id" => "did:plc:abc123"
      ...> })
      iex> json = Atex.DID.Document.to_json(doc)
      iex> json["id"]
      "did:plc:abc123"
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = doc) do
    base = %{
      "@context" => Map.get(doc, :"@context"),
      "id" => doc.id
    }

    base
    |> maybe_put("controller", doc.controller)
    |> maybe_put("alsoKnownAs", doc.also_known_as)
    |> maybe_put(
      "verificationMethod",
      doc.verification_method && Enum.map(doc.verification_method, &VerificationMethod.to_json/1)
    )
    |> maybe_put(
      "authentication",
      doc.authentication && Enum.map(doc.authentication, &serialise_authentication_entry/1)
    )
    |> maybe_put(
      "service",
      doc.service && Enum.map(doc.service, &Service.to_json/1)
    )
  end

  @doc """
  Validates that a DID document meets the minimum requirements for AT Protocol.

  Checks:

  - The document `id` matches the expected DID.
  - A valid atproto signing key exists (`verificationMethod` entry with id ending `#atproto`
    and `controller` matching the DID).
  - A valid PDS service entry exists (`service` entry with id ending `#atproto_pds`, type
    `"AtprotoPersonalDataServer"`, and a valid HTTPS or HTTP endpoint URL).

  Returns `:ok` or one of `{:error, :id_mismatch}`, `{:error, :no_signing_key}`,
  `{:error, :invalid_pds}`.
  """
  @spec validate_for_atproto(t(), String.t()) ::
          :ok | {:error, :id_mismatch | :no_signing_key | :invalid_pds}
  def validate_for_atproto(%__MODULE__{} = doc, did) do
    id_matches = doc.id == did

    valid_signing_key =
      Enum.any?(doc.verification_method || [], fn method ->
        String.ends_with?(method.id, "#atproto") and method.controller == did
      end)

    valid_pds_service =
      Enum.any?(doc.service || [], fn service ->
        String.ends_with?(service.id, "#atproto_pds") and
          service.type == "AtprotoPersonalDataServer" and
          valid_pds_endpoint?(service.service_endpoint)
      end)

    case {id_matches, valid_signing_key, valid_pds_service} do
      {true, true, true} -> :ok
      {false, _, _} -> {:error, :id_mismatch}
      {_, false, _} -> {:error, :no_signing_key}
      {_, _, false} -> {:error, :invalid_pds}
    end
  end

  @doc """
  Returns the AT Protocol handle claimed by this DID document, or `nil` if none is present.

  The handle is found in the `alsoKnownAs` array as a URI with the `at://` scheme followed
  by the handle hostname.  Per the atproto specification, only the first syntactically valid
  handle in the list is returned.

  > #### Note {: .info}
  >
  > A handle returned here is only a claim.  To confirm it, validate bidirectionally by
  > resolving the handle to a DID and checking it matches.  See
  > `Atex.IdentityResolver.Handle.resolve/2`.
  """
  @spec get_atproto_handle(t()) :: String.t() | nil
  def get_atproto_handle(%__MODULE__{also_known_as: nil}), do: nil

  def get_atproto_handle(%__MODULE__{} = doc) do
    Enum.find_value(doc.also_known_as, fn
      "at://" <> handle -> handle
      _ -> nil
    end)
  end

  @doc """
  Returns the PDS service endpoint URL from the DID document, or `nil` if not found.

  Looks for a `service` entry with id ending `#atproto_pds` and type
  `"AtprotoPersonalDataServer"`.
  """
  @spec get_pds_endpoint(t()) :: String.t() | nil
  def get_pds_endpoint(%__MODULE__{} = doc) do
    (doc.service || [])
    |> Enum.find(fn
      %Service{id: id, type: "AtprotoPersonalDataServer"} ->
        String.ends_with?(id, "#atproto_pds")

      _ ->
        false
    end)
    |> case do
      nil -> nil
      pds -> pds.service_endpoint
    end
  end

  @doc """
  Returns the atproto signing key from the DID document as a `JOSE.JWK`, or `nil`.

  Finds the first `verificationMethod` entry whose id ends with `#atproto`.  The public key
  is returned as a `JOSE.JWK` struct directly, since key decoding (including legacy formats)
  is performed at parse time in `new/1`.
  """
  @spec get_atproto_signing_key(t()) :: JOSE.JWK.t() | nil
  def get_atproto_signing_key(%__MODULE__{} = doc) do
    (doc.verification_method || [])
    |> Enum.find(fn %VerificationMethod{id: id} -> String.ends_with?(id, "#atproto") end)
    |> case do
      nil -> nil
      method -> method.public_key_jwk
    end
  end

  # Parse a raw verification method map, returning nil on failure.
  @spec parse_verification_method(map()) :: VerificationMethod.t() | nil
  defp parse_verification_method(raw) do
    case VerificationMethod.new(raw) do
      {:ok, vm} -> vm
      _ -> nil
    end
  end

  # Parse a raw service map, returning nil on failure.
  @spec parse_service(map()) :: Service.t() | nil
  defp parse_service(raw) do
    case Service.new(raw) do
      {:ok, svc} -> svc
      _ -> nil
    end
  end

  # Authentication entries can be either a URI string or a verification method map.
  @spec parse_authentication_entry(String.t() | map()) ::
          String.t() | VerificationMethod.t() | nil
  defp parse_authentication_entry(entry) when is_binary(entry), do: entry

  defp parse_authentication_entry(entry) when is_map(entry) do
    parse_verification_method(entry)
  end

  defp parse_authentication_entry(_), do: nil

  @spec serialise_authentication_entry(String.t() | VerificationMethod.t()) :: String.t() | map()
  defp serialise_authentication_entry(entry) when is_binary(entry), do: entry

  defp serialise_authentication_entry(%VerificationMethod{} = vm),
    do: VerificationMethod.to_json(vm)

  @spec maybe_put(map(), String.t(), any()) :: map()
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, []), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @spec valid_pds_endpoint?(String.t()) :: boolean()
  defp valid_pds_endpoint?(endpoint) do
    case URI.new(endpoint) do
      {:ok, uri} ->
        is_plain_uri =
          uri
          |> Map.from_struct()
          |> Enum.all?(fn
            {key, value} when key in [:userinfo, :path, :query, :fragment] -> is_nil(value)
            _ -> true
          end)

        uri.scheme in ["https", "http"] and is_plain_uri

      _ ->
        false
    end
  end
end

defimpl JSON.Encoder, for: Atex.DID.Document do
  def encode(value, encoder), do: JSON.encode!(Atex.DID.Document.to_json(value), encoder)
end
