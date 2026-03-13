defmodule Atex.PLC do
  @moduledoc """
  Client for the `did:plc` directory server HTTP API.

  `did:plc` is a self-authenticating DID method that is strongly-consistent,
  recoverable, and supports key rotation. The directory server receives and
  persists self-signed operation logs for each DID, starting with a genesis
  operation that defines the DID identifier itself.

  The API is permissionless, but only correctly-signed operations are accepted.
  The default server is `https://plc.directory`, but a custom host can be
  supplied via the `:host` option available on all functions.

  ## Options

  All functions accept an optional `opts` keyword list. Supported keys:

  - `:host` - Base URL of the PLC directory server. Defaults to
    `Atex.Config.directory_url/0`.

  ## Error returns

  Functions return `{:error, reason}` on failure. Common reasons:

  - `:not_found` - The DID is not registered (HTTP 404).
  - `:tombstoned` - The DID has been permanently deactivated (HTTP 410).
  - `:invalid_document` - The server returned a body that could not be parsed
    into an `Atex.DID.Document`.
  - `{:invalid_operation, message}` - The submitted operation was rejected by
    the server, with an explanatory message (HTTP 400).
  - `:invalid_operation` - The submitted operation was rejected without a
    message (HTTP 400).
  - `%{status: status, body: body}` - An unexpected HTTP response.
  - Any transport-level error from `Req`.
  """

  @type error_map() :: %{status: pos_integer(), body: any()}
  @type error() :: {:error, :not_found | :tombstoned | :invalid_document | error_map() | any()}
  @type create_op_error() ::
          {:error, {:invalid_operation, message :: String.t()} | :invalid_operation} | error()

  alias Atex.DID

  @doc """
  Resolves the DID Document for the given `did:plc` identifier.

  Fetches the current DID Document from the directory server and parses it into
  an `Atex.DID.Document` struct.

  ## Parameters

  - `did` - A `did:plc` identifier string.
  - `opts` - Optional keyword list. See module docs for supported keys.

  ## Examples

      iex> Atex.PLC.resolve_did("did:plc:ewvi7nxzyoun6zhxrhs64oiz")
      {:ok, %Atex.DID.Document{...}}

      iex> Atex.PLC.resolve_did("did:plc:doesnotexist")
      {:error, :not_found}
  """
  @spec resolve_did(String.t(), keyword()) :: {:ok, DID.Document.t()} | error()
  def resolve_did(did, opts \\ []) do
    opts
    |> host()
    |> URI.append_path("/#{did}")
    |> Req.get()
    |> handle_response()
    |> case do
      {:ok, body} ->
        case DID.Document.new(body) do
          {:ok, document} -> {:ok, document}
          {:error, _reason} -> {:error, :invalid_document}
        end

      e ->
        e
    end
  end

  @doc """
  Returns the current operation chain for the given DID.

  This is the authoritative, ordered sequence of operations that make up the
  DID's history. Unlike the audit log, nullified (overridden) operations are
  not included.

  ## Parameters

  - `did` - A `did:plc` identifier string.
  - `opts` - Optional keyword list. See module docs for supported keys.

  ## Examples

      iex> Atex.PLC.get_op_log("did:plc:ewvi7nxzyoun6zhxrhs64oiz")
      {:ok, [%{"type" => "plc_operation", ...}]}
  """
  @spec get_op_log(String.t(), keyword()) :: {:ok, any()} | error()
  def get_op_log(did, opts \\ []) do
    opts
    |> host()
    |> URI.append_path("/#{did}/log")
    |> Req.get()
    |> handle_response()
  end

  @doc """
  Returns the full audit log for the given DID.

  Includes every operation ever submitted for the DID, including those that
  have been nullified (overridden by a recovery or conflicting operation). Each
  entry is a log entry map containing the operation, its CID hash, a
  `nullified` flag, and the timestamp at which the directory received it.

  ## Parameters

  - `did` - A `did:plc` identifier string.
  - `opts` - Optional keyword list. See module docs for supported keys.

  ## Examples

      iex> Atex.PLC.get_audit_log("did:plc:ewvi7nxzyoun6zhxrhs64oiz")
      {:ok, [%{"did" => "did:plc:ewvi7nxzyoun6zhxrhs64oiz", "nullified" => false, ...}]}
  """
  @spec get_audit_log(String.t(), keyword()) :: {:ok, any()} | error()
  def get_audit_log(did, opts \\ []) do
    opts
    |> host()
    |> URI.append_path("/#{did}/log/audit")
    |> Req.get()
    |> handle_response()
  end

  @doc """
  Returns the most recent operation in the operation chain for the given DID.

  Useful for obtaining the `prev` CID reference required when constructing a
  new signed operation.

  ## Parameters

  - `did` - A `did:plc` identifier string.
  - `opts` - Optional keyword list. See module docs for supported keys.

  ## Examples

      iex> Atex.PLC.get_last_op("did:plc:ewvi7nxzyoun6zhxrhs64oiz")
      {:ok, %{"type" => "plc_operation", "prev" => nil, ...}}
  """
  @spec get_last_op(String.t(), keyword()) :: {:ok, any()} | error()
  def get_last_op(did, opts \\ []) do
    opts
    |> host()
    |> URI.append_path("/#{did}/log/last")
    |> Req.get()
    |> handle_response()
  end

  @doc """
  Returns the current PLC data for the given DID.

  The response is similar to an operation map but may omit some fields. It
  reflects the effective state derived from the current operation chain.

  ## Parameters

  - `did` - A `did:plc` identifier string.
  - `opts` - Optional keyword list. See module docs for supported keys.

  ## Examples

      iex> Atex.PLC.get_data("did:plc:ewvi7nxzyoun6zhxrhs64oiz")
      {:ok, %{"rotationKeys" => [...], "verificationMethods" => %{}, ...}}
  """
  @spec get_data(String.t(), keyword()) :: {:ok, any()} | error()
  def get_data(did, opts \\ []) do
    opts
    |> host()
    |> URI.append_path("/#{did}/data")
    |> Req.get()
    |> handle_response()
  end

  @doc """
  Bulk-fetches PLC operations across all DIDs.

  Results are paginated and returned as a list of log entry maps. Each entry
  contains the DID, the operation, its CID hash, a `nullified` flag, and the
  server-assigned `createdAt` timestamp.

  ## Parameters

  - `opts` - Optional keyword list. Supported keys:
    - `:host` - Base URL of the PLC directory server.
    - `:count` - Number of records to return (default: `10`, max: `1000`).
    - `:after` - ISO 8601 datetime string; return only operations indexed after
      this timestamp. Useful for cursor-based pagination.

  ## Examples

      iex> Atex.PLC.export(count: 2)
      {:ok, [%{"did" => "did:plc:...", "nullified" => false, ...}, ...]}

      iex> Atex.PLC.export(count: 100, after: "2024-01-01T00:00:00Z")
      {:ok, [...]}
  """
  @spec export(keyword()) :: {:ok, list(any())} | error()
  def export(opts \\ []) do
    {_, query} = Keyword.pop(opts, :host)
    query = URI.encode_query(query)

    opts
    |> host()
    |> URI.append_path("/export")
    |> URI.append_query(query)
    |> Req.get()
    |> handle_response(:jsonlines)
  end

  @doc """
  Submits a new signed PLC operation for the given DID.

  The `operation` map must be a fully-formed, self-signed PLC operation. The
  server validates the signature and the operation's position in the chain
  before accepting it.

  Supported operation types:

  - `"plc_operation"` - A standard update or genesis operation. Required fields:
    `type`, `rotationKeys`, `verificationMethods`, `alsoKnownAs`, `services`,
    `prev`, `sig`.
  - `"plc_tombstone"` - Permanently deactivates the DID. Required fields:
    `type`, `prev`, `sig`.
  - `"create"` - Legacy genesis operation format (still supported for
    historical resolution).

  ## Parameters

  - `did` - A `did:plc` identifier string.
  - `operation` - A map representing the signed PLC operation.
  - `opts` - Optional keyword list. See module docs for supported keys.

  ## Examples

      iex> op = %{
      ...>   "type" => "plc_operation",
      ...>   "rotationKeys" => ["did:key:..."],
      ...>   "verificationMethods" => %{"atproto" => "did:key:..."},
      ...>   "alsoKnownAs" => ["at://handle.bsky.social"],
      ...>   "services" => %{"atproto_pds" => %{"type" => "AtprotoPersonalDataServer", "endpoint" => "https://bsky.social"}},
      ...>   "prev" => "bafyreid6awsb6lzc54zxaq2roijyvpbjp5d6mii2xyztn55yli7htyjgqy",
      ...>   "sig" => "..."
      ...> }
      iex> Atex.PLC.create_op("did:plc:ewvi7nxzyoun6zhxrhs64oiz", op)
      {:ok, nil}

      iex> Atex.PLC.create_op("did:plc:ewvi7nxzyoun6zhxrhs64oiz", %{"sig" => "bad"})
      {:error, {:invalid_operation, "Invalid Signature"}}
  """
  @spec create_op(String.t(), map(), keyword()) :: {:ok, any()} | create_op_error()
  def create_op(did, operation, opts \\ []) do
    # TODO: add a signing key option to automatically sign operation?
    # TODO: require Operation struct

    opts
    |> host()
    |> URI.append_path("/#{did}")
    |> Req.post(json: operation)
    |> case do
      {:ok, %{status: 200, body: body}} when body in ["", nil] ->
        {:ok, nil}

      {:ok, %{status: 200, body: body}} ->
        JSON.decode(body)

      {:ok, %{status: 400, body: %{"message" => message}}} ->
        {:error, {:invalid_operation, message}}

      {:ok, %{status: 400}} ->
        {:error, :invalid_operation}

      result ->
        handle_response(result)
    end
  end

  @spec handle_response({:ok, Req.Response.t()} | {:error, any()}, :json | :jsonlines) ::
          {:ok, any()} | error()
  defp handle_response(response_tuple, expected_body_type \\ :json)

  # DID document response from PLC uses a non-standard Content-Type header which
  # Req doesn't recognise, so have to handle it manually.
  defp handle_response({:ok, %{status: 200, body: body}}, :json) when is_binary(body),
    do: JSON.decode(body)

  defp handle_response({:ok, %{status: 200, body: body}}, :json), do: {:ok, body}

  defp handle_response({:ok, %{status: 200, body: body}}, :jsonlines),
    do: {:ok, decode_jsonlines(body)}

  defp handle_response({:ok, %{status: 404}}, _type), do: {:error, :not_found}
  defp handle_response({:ok, %{status: 410}}, _type), do: {:error, :tombstoned}
  defp handle_response({:ok, resp}, _type), do: {:error, %{status: resp.status, body: resp.body}}
  defp handle_response({:error, reason}, _type), do: {:error, reason}

  @spec decode_jsonlines(binary()) :: [any()]
  defp decode_jsonlines(body) when is_binary(body) do
    body
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn line ->
      case JSON.decode(line) do
        {:ok, entry} -> [entry]
        {:error, _} -> []
      end
    end)
  end

  @spec host(keyword()) :: URI.t()
  defp host(opts) do
    host = Keyword.get(opts, :host, Atex.Config.directory_url())
    URI.new!(host)
  end
end
