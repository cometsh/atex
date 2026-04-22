defmodule Atex.OAuthTest do
  use ExUnit.Case, async: true

  alias Atex.OAuth

  describe "create_nonce/0" do
    test "returns a binary" do
      assert is_binary(OAuth.create_nonce())
    end

    test "returns unique values on each call" do
      refute OAuth.create_nonce() == OAuth.create_nonce()
    end
  end

  describe "session_keys_name/0" do
    test "returns the session keys atom" do
      assert OAuth.session_keys_name() == :atex_sessions
    end
  end

  describe "session_active_session_name/0" do
    test "returns the active session atom" do
      assert OAuth.session_active_session_name() == :atex_active_session
    end
  end
end
