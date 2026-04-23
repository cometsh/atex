defmodule Atex.ServiceAuthTest do
  use ExUnit.Case, async: true

  describe "validate_jwt/2" do
    test "returns {:error, :invalid_jwt} for a malformed token string" do
      assert {:error, :invalid_jwt} =
               Atex.ServiceAuth.validate_jwt("not.a.valid.jwt", aud: "did:web:example.com")
    end

    test "returns {:error, :invalid_jwt} for an empty string" do
      assert {:error, :invalid_jwt} =
               Atex.ServiceAuth.validate_jwt("", aud: "did:web:example.com")
    end
  end

  describe "validate_jwt/2 telemetry" do
    test "emits validate start and stop events even for invalid JWT" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-service-auth-#{inspect(ref)}",
        [
          [:atex, :service_auth, :validate, :start],
          [:atex, :service_auth, :validate, :stop]
        ],
        fn event, measurements, metadata, _ ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-service-auth-#{inspect(ref)}") end)

      Atex.ServiceAuth.validate_jwt("not.a.valid.jwt", aud: "did:web:example.com")

      assert_receive {:telemetry, [:atex, :service_auth, :validate, :start], %{system_time: _},
                      %{iss: nil, lxm: nil}}

      assert_receive {:telemetry, [:atex, :service_auth, :validate, :stop], %{duration: _},
                      %{iss: nil, lxm: nil}}
    end
  end
end
