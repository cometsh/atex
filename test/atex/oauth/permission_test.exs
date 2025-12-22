defmodule Atex.OAuth.PermissionTest do
  use ExUnit.Case, async: true
  alias Atex.OAuth.Permission
  doctest Permission

  describe "account/1" do
    test "requires `:attr`" do
      assert_raise ArgumentError, ~r/`:attr` must be provided/, fn ->
        Permission.account()
      end
    end

    test "requires valid `:attr`" do
      assert_raise ArgumentError, ~r/`:attr` must be `:email` or `:repo`/, fn ->
        Permission.account(attr: :foobar)
      end

      assert Permission.account(attr: :email)
    end

    test "requires valid `:action`" do
      assert_raise ArgumentError, ~r/`:action` must be `:read`, `:manage`, or `nil`/, fn ->
        Permission.account(attr: :email, action: :foobar)
      end

      assert Permission.account(attr: :email, action: :manage)
      assert Permission.account(attr: :repo, action: nil)
    end
  end

  describe "rpc/2" do
    test "requires at least `:aud` or `:inherit_aud`" do
      assert_raise ArgumentError, ~r/must specify either/, fn ->
        Permission.rpc("com.example.getProfile")
      end
    end

    test "disallows `:aud` and `:inherit_aud` at the same time" do
      assert_raise ArgumentError, ~r/cannot specify both/, fn ->
        Permission.rpc("com.example.getProfile", aud: "example", inherit_aud: true)
      end
    end

    test "disallows wildcard for `lxm` and `aud` at the same time" do
      assert_raise ArgumentError, ~r/wildcard `lxm` and wildcard `aud`/, fn ->
        Permission.rpc("*", aud: "*")
      end
    end
  end
end
