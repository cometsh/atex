defmodule Atex.IdentityResolverTelemetryTest do
  use ExUnit.Case, async: true

  describe "resolve/2 telemetry" do
    test "emits resolve start/stop and cache miss on first call" do
      ref = make_ref()
      identifier = "did:plc:test-#{inspect(ref)}"

      :telemetry.attach_many(
        "test-resolver-#{inspect(ref)}",
        [
          [:atex, :identity_resolver, :resolve, :start],
          [:atex, :identity_resolver, :resolve, :stop],
          [:atex, :identity_resolver, :cache, :miss],
          [:atex, :identity_resolver, :cache, :hit]
        ],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-resolver-#{inspect(ref)}") end)

      # resolve will fail because it's not a real DID, but telemetry still fires
      Atex.IdentityResolver.resolve(identifier)

      assert_receive {:telemetry, [:atex, :identity_resolver, :resolve, :start],
                      %{system_time: _}, %{identifier: ^identifier, identifier_type: :did}}

      assert_receive {:telemetry, [:atex, :identity_resolver, :cache, :miss], %{system_time: _},
                      %{identifier: ^identifier}}

      assert_receive {:telemetry, [:atex, :identity_resolver, :resolve, :stop], %{duration: _}, _}
    end

    test "emits cache hit event on repeated call for same identifier" do
      ref = make_ref()
      # Use a DID-style identifier that we can pre-populate in the cache
      identifier = "did:plc:cached-#{inspect(ref)}"

      :telemetry.attach(
        "test-resolver-cache-#{inspect(ref)}",
        [:atex, :identity_resolver, :cache, :hit],
        fn _event, _measurements, metadata, _ ->
          send(self(), {:cache_hit, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-resolver-cache-#{inspect(ref)}") end)

      # First call — cache miss, resolution fails (not a real DID)
      Atex.IdentityResolver.resolve(identifier)

      # Pre-populate the cache directly so the second call gets a hit
      identity = %Atex.IdentityResolver.Identity{did: identifier, handle: nil, document: nil}
      Atex.IdentityResolver.Cache.insert(identity)

      # Second call — cache hit
      Atex.IdentityResolver.resolve(identifier)

      assert_receive {:cache_hit, %{identifier: ^identifier}}
    end

    test "identifier_type is :handle for non-did identifiers" do
      ref = make_ref()
      identifier = "user.bsky.social"

      :telemetry.attach(
        "test-resolver-handle-#{inspect(ref)}",
        [:atex, :identity_resolver, :resolve, :start],
        fn _event, _measurements, metadata, _ ->
          send(self(), {:start, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-resolver-handle-#{inspect(ref)}") end)

      Atex.IdentityResolver.resolve(identifier)

      assert_receive {:start, %{identifier_type: :handle}}
    end
  end
end
