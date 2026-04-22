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
end
