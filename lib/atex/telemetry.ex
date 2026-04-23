defmodule Atex.Telemetry do
  @moduledoc """
  Telemetry instrumentation for Atex.

  Atex emits `:telemetry` events throughout its subsystems. To receive events,
  attach handlers using `:telemetry.attach/4` or `:telemetry.attach_many/4`.

  `:telemetry` is an **optional dependency**. If it is not present in your
  application's deps, all instrumentation calls compile to no-ops with zero
  runtime overhead. Add it to your `mix.exs` to enable instrumentation:

      {:telemetry, "~> 1.0"}

  ## Event catalogue

  ### XRPC

  #### `[:atex, :xrpc, :request, :start | :stop | :exception]`

  Emitted for every outgoing XRPC HTTP request (all client types).

  - **start measurements:** `%{system_time: integer()}`
  - **stop measurements:** `%{duration: integer()}`
  - **exception measurements:** `%{duration: integer()}`
  - **metadata (all events):** `%{method: :get | :post, resource: String.t(), endpoint: String.t(), client_type: :login | :oauth | :service_auth | :unauthed}`
  - **stop additional metadata:** `%{status: integer()}`
  - **exception additional metadata:** `%{kind: :error, reason: term(), stacktrace: list()}`

  #### `[:atex, :xrpc, :token_refresh, :start | :stop | :exception]`

  Emitted when a client performs a token refresh (`LoginClient` or `OAuthClient`).

  - **start measurements:** `%{system_time: integer()}`
  - **stop measurements:** `%{duration: integer()}`
  - **metadata:** `%{client_type: :login | :oauth}`

  ### Identity Resolver

  #### `[:atex, :identity_resolver, :resolve, :start | :stop | :exception]`

  Emitted for every call to `Atex.IdentityResolver.resolve/2`.

  - **start measurements:** `%{system_time: integer()}`
  - **stop measurements:** `%{duration: integer()}`
  - **metadata:** `%{identifier: String.t(), identifier_type: :did | :handle}`

  #### `[:atex, :identity_resolver, :cache, :hit | :miss]`

  Emitted at the cache check branch inside `resolve/2`. `:hit` means the result
  was served from cache; `:miss` means a fresh resolution was performed (including
  when `skip_cache: true` is passed).

  - **measurements:** `%{system_time: integer()}`
  - **metadata:** `%{identifier: String.t()}`

  ### OAuth

  All OAuth spans share:

  - **start measurements:** `%{system_time: integer()}`
  - **stop measurements:** `%{duration: integer()}`
  - **metadata:** `%{issuer: String.t() | nil}`

  #### `[:atex, :oauth, :authorization_url, :start | :stop | :exception]`

  Wraps `Atex.OAuth.Flow.create_authorization_url/5` (PAR request + URL construction).

  #### `[:atex, :oauth, :code_exchange, :start | :stop | :exception]`

  Wraps `Atex.OAuth.Flow.validate_authorization_code/5`.

  #### `[:atex, :oauth, :token_refresh, :start | :stop | :exception]`

  Wraps `Atex.OAuth.Flow.refresh_token/5`.

  #### `[:atex, :oauth, :token_revocation, :start | :stop | :exception]`

  Wraps `Atex.OAuth.Flow.revoke_tokens/2`.

  ### Service Auth

  #### `[:atex, :service_auth, :validate, :start | :stop | :exception]`

  Wraps `Atex.ServiceAuth.validate_jwt/2`.

  - **start measurements:** `%{system_time: integer()}`
  - **stop measurements:** `%{duration: integer()}`
  - **metadata:** `%{iss: String.t() | nil, lxm: String.t() | nil}`

  ## Example handler

      :telemetry.attach_many(
        "my-app-atex-handler",
        [
          [:atex, :xrpc, :request, :stop],
          [:atex, :identity_resolver, :resolve, :stop]
        ],
        fn event, measurements, metadata, _config ->
          Logger.debug(
            "Atex event: \#{inspect(event)} " <>
              "duration=\#{measurements.duration} " <>
              "metadata=\#{inspect(metadata)}"
          )
        end,
        nil
      )
  """

  @telemetry_available Code.ensure_loaded?(:telemetry)

  if @telemetry_available do
    @doc """
    Execute a telemetry event.

    Delegates to `:telemetry.execute/3`. No-op when `:telemetry` is not loaded.
    """
    @spec execute(list(atom()), map(), map()) :: :ok
    def execute(event, measurements, metadata),
      do: :telemetry.execute(event, measurements, metadata)

    @doc """
    Span a block with telemetry start/stop/exception events.

    Emits `event_prefix ++ [:start]` before calling `fun` and `event_prefix ++ [:stop]`
    after it returns. The `:start` event carries `%{system_time: System.system_time()}` as
    measurements and `start_metadata` as metadata. The `:stop` event carries
    `%{duration: duration}` (in native time units) and the result of merging
    `start_metadata` with the extra metadata returned by `fun`.

    `fun` must return `{result, extra_stop_metadata}`. This function returns `result`.

    No-op (calls `fun` and returns result) when `:telemetry` is not loaded.
    """
    @spec span(list(atom()), map(), (-> {result, map()})) :: result when result: any()
    def span(event_prefix, start_metadata, fun) do
      start_time = System.monotonic_time()

      :telemetry.execute(
        event_prefix ++ [:start],
        %{system_time: System.system_time()},
        start_metadata
      )

      try do
        {result, extra_stop_metadata} = fun.()
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          event_prefix ++ [:stop],
          %{duration: duration},
          Map.merge(start_metadata, extra_stop_metadata)
        )

        result
      rescue
        exception ->
          duration = System.monotonic_time() - start_time

          :telemetry.execute(
            event_prefix ++ [:exception],
            %{duration: duration},
            Map.merge(start_metadata, %{
              kind: :error,
              reason: exception,
              stacktrace: __STACKTRACE__
            })
          )

          reraise exception, __STACKTRACE__
      catch
        kind, reason ->
          duration = System.monotonic_time() - start_time

          :telemetry.execute(
            event_prefix ++ [:exception],
            %{duration: duration},
            Map.merge(start_metadata, %{
              kind: kind,
              reason: reason,
              stacktrace: __STACKTRACE__
            })
          )

          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    end

    @doc """
    Attach telemetry instrumentation to a `Req.Request`.

    Adds request and response steps that emit `[:atex, :xrpc, :request, ...]`
    events. Pass `client_type:` to identify the XRPC client variant.

    No-op when `:telemetry` is not loaded.

    ## Options

    - `:client_type` — one of `:login`, `:oauth`, `:service_auth`, `:unauthed`
      (default: `:unknown`)

    ## Example

        Req.new(method: :get, url: url)
        |> Atex.Telemetry.attach_req_plugin(client_type: :login)
        |> Req.request()
    """
    @spec attach_req_plugin(Req.Request.t(), keyword()) :: Req.Request.t()
    def attach_req_plugin(req, opts \\ []) do
      client_type = Keyword.get(opts, :client_type, :unknown)

      req
      |> Req.Request.append_request_steps(atex_telemetry_start: &run_start_step(&1, client_type))
      |> Req.Request.prepend_response_steps(atex_telemetry_stop: &run_stop_step/1)
      |> Req.Request.prepend_error_steps(atex_telemetry_stop: &run_stop_step/1)
    end

    defp run_start_step(req, client_type) do
      start_time = System.monotonic_time()
      path = req.url.path || ""
      resource = String.replace_prefix(path, "/xrpc/", "")

      endpoint =
        URI.to_string(%URI{scheme: req.url.scheme, host: req.url.host, port: req.url.port})

      :telemetry.execute(
        [:atex, :xrpc, :request, :start],
        %{system_time: System.system_time()},
        %{method: req.method, resource: resource, endpoint: endpoint, client_type: client_type}
      )

      req
      |> Req.Request.put_private(:atex_start_time, start_time)
      |> Req.Request.put_private(:atex_metadata, %{
        method: req.method,
        resource: resource,
        endpoint: endpoint,
        client_type: client_type
      })
    end

    defp run_stop_step({req, response}) do
      start_time = Req.Request.get_private(req, :atex_start_time)
      base_metadata = Req.Request.get_private(req, :atex_metadata) || %{}

      if start_time do
        duration = System.monotonic_time() - start_time

        if match?(%Req.Response{}, response) do
          :telemetry.execute(
            [:atex, :xrpc, :request, :stop],
            %{duration: duration},
            Map.put(base_metadata, :status, response.status)
          )
        else
          :telemetry.execute(
            [:atex, :xrpc, :request, :exception],
            %{duration: duration},
            # stacktrace unavailable in Req error steps — transport errors don't have one
            Map.merge(base_metadata, %{kind: :error, reason: response, stacktrace: []})
          )
        end
      end

      {req, response}
    end
  else
    @doc false
    @spec execute(list(atom()), map(), map()) :: :ok
    def execute(_event, _measurements, _metadata), do: :ok

    @doc false
    @spec span(list(atom()), map(), (-> {result, map()})) :: result when result: any()
    def span(_event_prefix, _start_metadata, fun) do
      {result, _meta} = fun.()
      result
    end

    @doc false
    @spec attach_req_plugin(Req.Request.t(), keyword()) :: Req.Request.t()
    def attach_req_plugin(req, _opts \\ []), do: req
  end
end
