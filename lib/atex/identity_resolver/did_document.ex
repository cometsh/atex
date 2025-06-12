defmodule Atex.IdentityResolver.DIDDocument do
  @moduledoc """
  Struct and schema for describing and validating a [DID document](https://github.com/w3c/did-wg/blob/main/did-explainer.md#did-documents).
  """
  import Peri
  use TypedStruct

  defschema :schema, %{
    "@context": {:required, {:list, Atex.Peri.uri()}},
    id: {:required, :string},
    controller: {:either, {Atex.Peri.did(), {:list, Atex.Peri.did()}}},
    also_known_as: {:list, Atex.Peri.uri()},
    verification_method: {:list, get_schema(:verification_method)},
    authentication: {:list, {:either, {Atex.Peri.uri(), get_schema(:verification_method)}}},
    service: {:list, get_schema(:service)}
  }

  defschema :verification_method, %{
    id: {:required, Atex.Peri.uri()},
    type: {:required, :string},
    controller: {:required, Atex.Peri.did()},
    public_key_multibase: :string,
    public_key_jwk: :map
  }

  defschema :service, %{
    id: {:required, Atex.Peri.uri()},
    type: {:required, {:either, {:string, {:list, :string}}}},
    service_endpoint:
      {:required,
       {:oneof,
        [
          Atex.Peri.uri(),
          {:map, Atex.Peri.uri()},
          {:list, {:either, {Atex.Peri.uri(), {:map, Atex.Peri.uri()}}}}
        ]}}
  }

  @type verification_method() :: %{
          required(:id) => String.t(),
          required(:type) => String.t(),
          required(:controller) => String.t(),
          optional(:public_key_multibase) => String.t(),
          optional(:public_key_jwk) => map()
        }

  @type service() :: %{
          required(:id) => String.t(),
          required(:type) => String.t() | list(String.t()),
          required(:service_endpoint) =>
            String.t()
            | %{String.t() => String.t()}
            | list(String.t() | %{String.t() => String.t()})
        }

  typedstruct do
    field :"@context", list(String.t()), enforce: true
    field :id, String.t(), enforce: true
    field :controller, String.t() | list(String.t())
    field :also_known_as, list(String.t())
    field :verification_method, list(verification_method())
    field :authentication, list(String.t() | verification_method())
    field :service, list(service())
  end

  # Temporary until this issue is fixed: https://github.com/zoedsoupe/peri/issues/30
  def new(params) do
    params
    |> Recase.Enumerable.atomize_keys(&Recase.to_snake/1)
    |> then(&struct(__MODULE__, &1))
  end

  @spec from_json(map()) :: {:ok, t()} | {:error, Peri.Error.t()}
  def from_json(%{} = map) do
    map
    # TODO: `atomize_keys` instead? Peri doesn't convert nested schemas to atoms but does for the base schema.
    # Smells like a PR if I've ever smelt one...
    |> Recase.Enumerable.convert_keys(&Recase.to_snake/1)
    |> schema()
    |> case do
      # {:ok, params} -> {:ok, struct(__MODULE__, params)}
      {:ok, params} -> {:ok, new(params)}
      e -> e
    end
  end

  @spec validate_for_atproto(t(), String.t()) :: any()
  def validate_for_atproto(%__MODULE__{} = doc, did) do
    # TODO: make sure this is  ok
    id_matches = doc.id == did

    valid_signing_key =
      Enum.any?(doc.verification_method, fn method ->
        String.ends_with?(method.id, "#atproto") and method.controller == did
      end)

    valid_pds_service =
      Enum.any?(doc.service, fn service ->
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
  Get the associated ATProto handle in the DID document.

  ATProto dictates that only the first valid handle is to be used, so this
  follows that rule.

  > #### Note {: .info}
  >
  > While DID documents are fairly authoritative, you need to make sure to
  > validate the handle bidirectionally. See
  > `Atex.IdentityResolver.Handle.resolve/2`.
  """
  @spec get_atproto_handle(t()) :: String.t() | nil
  def get_atproto_handle(%__MODULE__{also_known_as: nil}), do: nil

  def get_atproto_handle(%__MODULE__{} = doc) do
    Enum.find_value(doc.also_known_as, fn
      # TODO: make sure no path or other URI parts
      "at://" <> handle -> handle
      _ -> nil
    end)
  end

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
    end
  end
end
