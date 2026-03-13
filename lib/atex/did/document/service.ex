defmodule Atex.DID.Document.Service do
  @moduledoc """
  Struct and schema for a `service` entry in a DID document.

  Each service entry describes a network endpoint associated with the DID subject.
  In atproto, the most relevant service is the PDS (Personal Data Server), identified
  by the `#atproto_pds` fragment and type `"AtprotoPersonalDataServer"`.

  ## Fields

  - `:id` - URI identifying the service, typically a DID fragment (e.g. `"#atproto_pds"`
    or the fully-qualified form `"did:plc:abc123#atproto_pds"`).
  - `:type` - Service type string or list of type strings.
  - `:service_endpoint` - The endpoint URI, a map of URIs, or a list of either.
  """
  import Peri
  use TypedStruct

  @typedoc "A service endpoint: a URI string, a map of URI strings, or a list of either."
  @type endpoint() ::
          String.t()
          | %{String.t() => String.t()}
          | list(String.t() | %{String.t() => String.t()})

  defschema :schema, %{
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

  typedstruct do
    field :id, String.t(), enforce: true
    field :type, String.t() | list(String.t()), enforce: true
    field :service_endpoint, endpoint(), enforce: true
  end

  @doc """
  Validates and builds a `Service` struct from a map (snake_case or camelCase keys).

  Returns `{:ok, t()}` on success, or `{:error, Peri.Error.t()}` on validation failure.

  ## Examples

      iex> Atex.DID.Document.Service.new(%{
      ...>   "id" => "#atproto_pds",
      ...>   "type" => "AtprotoPersonalDataServer",
      ...>   "serviceEndpoint" => "https://pds.example.com"
      ...> })
      {:ok, %Atex.DID.Document.Service{
        id: "#atproto_pds",
        type: "AtprotoPersonalDataServer",
        service_endpoint: "https://pds.example.com"
      }}
  """
  @spec new(map()) :: {:ok, t()} | {:error, Peri.Error.t()}
  def new(%{} = map) do
    map
    |> Recase.Enumerable.convert_keys(&Recase.to_snake/1)
    |> schema()
    |> case do
      {:ok, params} -> {:ok, struct(__MODULE__, params)}
      e -> e
    end
  end

  @doc """
  Converts a `Service` struct to a camelCase map suitable for JSON serialisation.

  ## Examples

      iex> svc = %Atex.DID.Document.Service{
      ...>   id: "#atproto_pds",
      ...>   type: "AtprotoPersonalDataServer",
      ...>   service_endpoint: "https://pds.example.com"
      ...> }
      iex> Atex.DID.Document.Service.to_json(svc)
      %{
        "id" => "#atproto_pds",
        "type" => "AtprotoPersonalDataServer",
        "serviceEndpoint" => "https://pds.example.com"
      }
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = service) do
    %{
      "id" => service.id,
      "type" => service.type,
      "serviceEndpoint" => service.service_endpoint
    }
  end
end

defimpl JSON.Encoder, for: Atex.DID.Document.Service do
  def encode(value, encoder), do: JSON.encode!(Atex.DID.Document.Service.to_json(value), encoder)
end
