defmodule Atex.TelemetryTest do
  use ExUnit.Case, async: true

  describe "execute/3" do
    test "emits a telemetry event" do
      ref = make_ref()

      :telemetry.attach(
        "test-execute-#{inspect(ref)}",
        [:atex, :test, :event],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-execute-#{inspect(ref)}") end)

      Atex.Telemetry.execute([:atex, :test, :event], %{count: 1}, %{key: "val"})

      assert_receive {:telemetry, [:atex, :test, :event], %{count: 1}, %{key: "val"}}
    end
  end

  describe "span/3" do
    test "emits start and stop events and returns the result" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-span-#{inspect(ref)}",
        [[:atex, :test, :span, :start], [:atex, :test, :span, :stop]],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-span-#{inspect(ref)}") end)

      result =
        Atex.Telemetry.span([:atex, :test, :span], %{key: "start_val"}, fn ->
          {{:ok, :returned_value}, %{extra: "stop_val"}}
        end)

      assert result == {:ok, :returned_value}

      assert_receive {:telemetry, [:atex, :test, :span, :start], %{system_time: _},
                      %{key: "start_val"}}

      assert_receive {:telemetry, [:atex, :test, :span, :stop], %{duration: _},
                      %{key: "start_val", extra: "stop_val"}}
    end
  end

  defmodule TransportErrorPlug do
    @moduledoc false
    def init(opts), do: opts
    def call(conn, _opts), do: Req.Test.transport_error(conn, :closed)
  end

  defmodule OkPlug do
    @moduledoc false
    import Plug.Conn
    def init(opts), do: opts

    def call(conn, _opts) do
      conn |> send_resp(200, Jason.encode!(%{ok: true}))
    end
  end

  defmodule ErrorPlug do
    @moduledoc false
    import Plug.Conn
    def init(opts), do: opts

    def call(conn, _opts) do
      conn |> send_resp(500, Jason.encode!(%{error: "ServerError"}))
    end
  end

  describe "attach_req_plugin/2" do
    test "emits start and stop events on success" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-plugin-success-#{inspect(ref)}",
        [[:atex, :xrpc, :request, :start], [:atex, :xrpc, :request, :stop]],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-plugin-success-#{inspect(ref)}") end)

      req =
        Req.new(
          method: :get,
          url: "http://bsky.social/xrpc/app.bsky.actor.getProfile",
          plug: OkPlug
        )
        |> Atex.Telemetry.attach_req_plugin(client_type: :login)

      {:ok, _response} = Req.request(req)

      assert_receive {:telemetry, [:atex, :xrpc, :request, :start], %{system_time: _},
                      %{
                        method: :get,
                        resource: "app.bsky.actor.getProfile",
                        endpoint: "http://bsky.social",
                        client_type: :login
                      }}

      assert_receive {:telemetry, [:atex, :xrpc, :request, :stop], %{duration: _},
                      %{
                        status: 200,
                        method: :get,
                        resource: "app.bsky.actor.getProfile",
                        endpoint: "http://bsky.social",
                        client_type: :login
                      }}
    end

    test "includes status code from non-200 responses in stop event" do
      ref = make_ref()

      :telemetry.attach(
        "test-plugin-error-#{inspect(ref)}",
        [:atex, :xrpc, :request, :stop],
        fn _event, _measurements, metadata, _ ->
          send(self(), {:stop, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-plugin-error-#{inspect(ref)}") end)

      req =
        Req.new(
          method: :get,
          url: "http://bsky.social/xrpc/app.bsky.actor.getProfile",
          plug: ErrorPlug,
          retry: false
        )
        |> Atex.Telemetry.attach_req_plugin(client_type: :login)

      {:ok, _response} = Req.request(req)

      assert_receive {:stop,
                      %{status: 500, resource: "app.bsky.actor.getProfile", client_type: :login}}
    end

    test "emits exception event on transport error" do
      ref = make_ref()

      :telemetry.attach(
        "test-plugin-exception-#{inspect(ref)}",
        [:atex, :xrpc, :request, :exception],
        fn _event, _measurements, metadata, _ ->
          send(self(), {:exception, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-plugin-exception-#{inspect(ref)}") end)

      req =
        Req.new(
          method: :get,
          url: "http://bsky.social/xrpc/app.bsky.actor.getProfile",
          plug: TransportErrorPlug,
          retry: false
        )
        |> Atex.Telemetry.attach_req_plugin(client_type: :login)

      {:error, _reason} = Req.request(req)

      assert_receive {:exception,
                      %{
                        kind: :error,
                        reason: %Req.TransportError{reason: :closed},
                        resource: "app.bsky.actor.getProfile",
                        client_type: :login
                      }}
    end

    test "no-op when telemetry not attached — request still succeeds" do
      req =
        Req.new(
          method: :get,
          url: "http://bsky.social/xrpc/app.bsky.actor.getProfile",
          plug: OkPlug
        )
        |> Atex.Telemetry.attach_req_plugin(client_type: :login)

      assert {:ok, %{status: 200}} = Req.request(req)
    end
  end

  describe "XRPC client instrumentation" do
    defmodule XRPCPlug do
      @moduledoc false
      import Plug.Conn
      def init(opts), do: opts

      def call(conn, _opts) do
        conn |> send_resp(200, Jason.encode!(%{did: "did:plc:abc", handle: "user.bsky.social"}))
      end
    end

    test "LoginClient emits request start/stop events" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-login-client-#{inspect(ref)}",
        [[:atex, :xrpc, :request, :start], [:atex, :xrpc, :request, :stop]],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-login-client-#{inspect(ref)}") end)

      client = Atex.XRPC.LoginClient.new("http://bsky.social", "fake-token", nil)

      Atex.XRPC.get(client, "com.atproto.identity.resolveHandle",
        plug: XRPCPlug,
        params: [handle: "user.bsky.social"]
      )

      assert_receive {:telemetry, [:atex, :xrpc, :request, :start], %{system_time: _},
                      %{
                        method: :get,
                        resource: "com.atproto.identity.resolveHandle",
                        client_type: :login
                      }}

      assert_receive {:telemetry, [:atex, :xrpc, :request, :stop], %{duration: _},
                      %{status: 200, client_type: :login}}
    end

    test "unauthed_get emits request start/stop events" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-unauthed-#{inspect(ref)}",
        [[:atex, :xrpc, :request, :start], [:atex, :xrpc, :request, :stop]],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-unauthed-#{inspect(ref)}") end)

      Atex.XRPC.unauthed_get("http://bsky.social", "com.atproto.identity.resolveHandle",
        plug: XRPCPlug,
        params: [handle: "user.bsky.social"]
      )

      assert_receive {:telemetry, [:atex, :xrpc, :request, :start], %{system_time: _},
                      %{resource: "com.atproto.identity.resolveHandle", client_type: :unauthed}}

      assert_receive {:telemetry, [:atex, :xrpc, :request, :stop], %{duration: _},
                      %{status: 200, client_type: :unauthed}}
    end
  end
end
