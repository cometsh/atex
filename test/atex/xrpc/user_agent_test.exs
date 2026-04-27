defmodule Atex.XRPC.UserAgentTest do
  use ExUnit.Case, async: false

  # Captures the user-agent header sent by a request and sends it to the test process.
  defmodule CaptureUAPlug do
    @moduledoc false
    import Plug.Conn
    def init(opts), do: opts
    def call(conn, _opts) do
      send(self(), {:user_agent, get_req_header(conn, "user-agent")})
      send_resp(conn, 200, Jason.encode!(%{}))
    end
  end

  defp version, do: to_string(Application.spec(:atex, :vsn))

  describe "Atex.Config.user_agent/0" do
    test "returns atex/<version> when :user_agent not configured" do
      assert Atex.Config.user_agent() == "atex/#{version()}"
    end

    test "returns custom ua with atex suffix when :user_agent is configured" do
      Application.put_env(:atex, :user_agent, "my-app/1.0.0")
      on_exit(fn -> Application.delete_env(:atex, :user_agent) end)

      assert Atex.Config.user_agent() == "my-app/1.0.0 (atex/#{version()})"
    end
  end

  describe "Atex.XRPC.attach_user_agent/1" do
    test "sets user-agent header to default" do
      expected_ua = "atex/#{version()}"

      req =
        Req.new(
          method: :get,
          url: "http://example.com/xrpc/com.example.test",
          plug: CaptureUAPlug
        )
        |> Atex.XRPC.attach_user_agent()

      {:ok, _} = Req.request(req)

      assert_receive {:user_agent, [^expected_ua]}
    end

    test "sets user-agent header to configured value" do
      expected_ua = "my-app/1.0.0 (atex/#{version()})"
      Application.put_env(:atex, :user_agent, "my-app/1.0.0")
      on_exit(fn -> Application.delete_env(:atex, :user_agent) end)

      req =
        Req.new(
          method: :get,
          url: "http://example.com/xrpc/com.example.test",
          plug: CaptureUAPlug
        )
        |> Atex.XRPC.attach_user_agent()

      {:ok, _} = Req.request(req)

      assert_receive {:user_agent, [^expected_ua]}
    end
  end

  describe "UnauthedClient" do
    test "sends default user-agent" do
      expected_ua = "atex/#{version()}"
      client = Atex.XRPC.UnauthedClient.new("http://example.com")
      Atex.XRPC.get(client, "com.example.test", plug: CaptureUAPlug)
      assert_receive {:user_agent, [^expected_ua]}
    end

    test "sends configured user-agent" do
      expected_ua = "my-app/1.0.0 (atex/#{version()})"
      Application.put_env(:atex, :user_agent, "my-app/1.0.0")
      on_exit(fn -> Application.delete_env(:atex, :user_agent) end)

      client = Atex.XRPC.UnauthedClient.new("http://example.com")
      Atex.XRPC.get(client, "com.example.test", plug: CaptureUAPlug)
      assert_receive {:user_agent, [^expected_ua]}
    end
  end

  describe "LoginClient" do
    test "sends default user-agent" do
      expected_ua = "atex/#{version()}"
      client = Atex.XRPC.LoginClient.new("http://example.com", "fake-access-token", nil)
      Atex.XRPC.get(client, "com.example.test", plug: CaptureUAPlug)
      assert_receive {:user_agent, [^expected_ua]}
    end

    test "sends configured user-agent" do
      expected_ua = "my-app/1.0.0 (atex/#{version()})"
      Application.put_env(:atex, :user_agent, "my-app/1.0.0")
      on_exit(fn -> Application.delete_env(:atex, :user_agent) end)

      client = Atex.XRPC.LoginClient.new("http://example.com", "fake-access-token", nil)
      Atex.XRPC.get(client, "com.example.test", plug: CaptureUAPlug)
      assert_receive {:user_agent, [^expected_ua]}
    end
  end
end
