defmodule Atex.XRPC.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  # ---------------------------------------------------------------------------
  # Stub lexicon modules used by macro-expansion tests.
  # These live outside of the test module so they are available at compile time
  # when the inline router modules below are defined.
  # ---------------------------------------------------------------------------

  defmodule StubLexicon do
    @moduledoc false
    def id, do: "com.example.stubQuery"

    defmodule Params do
      @moduledoc false
      def from_json(%{"name" => name}) when is_binary(name), do: {:ok, %{name: name}}
      def from_json(_), do: {:error, "name is required and must be a string"}
    end
  end

  defmodule StubProcedureLexicon do
    @moduledoc false
    def id, do: "com.example.stubProcedure"

    defmodule Params do
      @moduledoc false
      # Query params arrive as strings; version is optional.
      def from_json(%{"version" => v}) when is_binary(v) or is_integer(v),
        do: {:ok, %{version: v}}

      def from_json(_), do: {:ok, %{}}
    end

    defmodule Input do
      @moduledoc false
      def from_json(%{"text" => t}) when is_binary(t), do: {:ok, %{text: t}}
      def from_json(_), do: {:error, "text is required"}
    end
  end

  defmodule StubNoParamsLexicon do
    @moduledoc false
    def id, do: "com.example.noParams"
  end

  # ---------------------------------------------------------------------------
  # Router fixtures
  # ---------------------------------------------------------------------------

  defmodule StringNSIDRouter do
    use Plug.Router
    use Atex.XRPC.Router, plug_aud: false

    plug :match
    plug :dispatch

    query "com.example.stringQuery" do
      send_resp(conn, 200, "query-ok")
    end

    procedure "com.example.stringProcedure" do
      send_resp(conn, 200, "procedure-ok")
    end

    match _ do
      send_resp(conn, 404, "not found")
    end
  end

  defmodule ModuleRouter do
    use Plug.Router
    use Atex.XRPC.Router, plug_aud: false

    plug Plug.Parsers,
      parsers: [:json],
      pass: ["application/json"],
      json_decoder: Jason

    plug :match
    plug :dispatch

    query Atex.XRPC.RouterTest.StubLexicon do
      send_resp(conn, 200, Jason.encode!(conn.assigns[:params]))
    end

    procedure Atex.XRPC.RouterTest.StubProcedureLexicon do
      result = %{
        params: conn.assigns[:params],
        body: conn.assigns[:body]
      }

      send_resp(conn, 200, Jason.encode!(result))
    end

    query Atex.XRPC.RouterTest.StubNoParamsLexicon do
      has_params = Map.has_key?(conn.assigns, :params)
      send_resp(conn, 200, if(has_params, do: "has-params", else: "no-params"))
    end

    match _ do
      send_resp(conn, 404, "not found")
    end
  end

  defmodule RequireAuthRouter do
    use Plug.Router
    use Atex.XRPC.Router, plug_aud: false

    plug :match
    plug :dispatch

    query "com.example.authed", require_auth: true do
      send_resp(conn, 200, "authed-ok")
    end

    query "com.example.softAuth" do
      has_jwt = Map.has_key?(conn.assigns, :current_jwt)
      send_resp(conn, 200, if(has_jwt, do: "has-jwt", else: "no-jwt"))
    end

    match _ do
      send_resp(conn, 404, "not found")
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp call(router, method, path, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])
    body = Keyword.get(opts, :body, "")
    query_string = Keyword.get(opts, :query_string, "")

    conn =
      method
      |> conn(path <> if(query_string != "", do: "?#{query_string}", else: ""), body)
      |> Map.put(:req_headers, headers)

    conn =
      if aud = Keyword.get(opts, :xrpc_aud) do
        put_private(conn, :xrpc_aud, aud)
      else
        conn
      end

    router.call(conn, router.init([]))
  end

  defp json_body(conn) do
    Jason.decode!(conn.resp_body)
  end

  # ---------------------------------------------------------------------------
  # Tests: string NSID routing
  # ---------------------------------------------------------------------------

  describe "query with string NSID" do
    test "routes GET /xrpc/<nsid>" do
      conn = call(StringNSIDRouter, :get, "/xrpc/com.example.stringQuery")
      assert conn.status == 200
      assert conn.resp_body == "query-ok"
    end

    test "does not match POST" do
      conn = call(StringNSIDRouter, :post, "/xrpc/com.example.stringQuery")
      assert conn.status == 404
    end

    test "does not match unrelated paths" do
      conn = call(StringNSIDRouter, :get, "/xrpc/com.example.other")
      assert conn.status == 404
    end
  end

  describe "procedure with string NSID" do
    test "routes POST /xrpc/<nsid>" do
      conn = call(StringNSIDRouter, :post, "/xrpc/com.example.stringProcedure")
      assert conn.status == 200
      assert conn.resp_body == "procedure-ok"
    end

    test "does not match GET" do
      conn = call(StringNSIDRouter, :get, "/xrpc/com.example.stringProcedure")
      assert conn.status == 404
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: module atom routing and param/body validation
  # ---------------------------------------------------------------------------

  describe "query with lexicon module (has Params)" do
    test "validates and assigns params on success" do
      conn = call(ModuleRouter, :get, "/xrpc/com.example.stubQuery", query_string: "name=alice")
      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"name" => "alice"}
    end

    test "halts with 400 on invalid params" do
      conn = call(ModuleRouter, :get, "/xrpc/com.example.stubQuery")
      assert conn.status == 400
      body = json_body(conn)
      assert body["error"] == "InvalidRequest"
      assert is_binary(body["message"])
    end
  end

  describe "query with lexicon module (no Params submodule)" do
    test "does not assign :params" do
      conn = call(ModuleRouter, :get, "/xrpc/com.example.noParams")
      assert conn.status == 200
      assert conn.resp_body == "no-params"
    end
  end

  describe "procedure with lexicon module (has Params and Input)" do
    test "validates and assigns body on success" do
      conn =
        call(ModuleRouter, :post, "/xrpc/com.example.stubProcedure",
          body: Jason.encode!(%{"text" => "hello"}),
          headers: [{"content-type", "application/json"}]
        )

      assert conn.status == 200
      result = Jason.decode!(conn.resp_body)
      assert result["body"] == %{"text" => "hello"}
    end

    test "assigns params when query string present" do
      conn =
        call(ModuleRouter, :post, "/xrpc/com.example.stubProcedure",
          query_string: "version=1",
          body: Jason.encode!(%{"text" => "hello"}),
          headers: [{"content-type", "application/json"}]
        )

      assert conn.status == 200
      result = Jason.decode!(conn.resp_body)
      assert result["params"] == %{"version" => "1"}
    end

    test "halts with 400 on invalid body" do
      conn =
        call(ModuleRouter, :post, "/xrpc/com.example.stubProcedure",
          body: Jason.encode!(%{"wrong" => "field"}),
          headers: [{"content-type", "application/json"}]
        )

      assert conn.status == 400
      body = json_body(conn)
      assert body["error"] == "InvalidRequest"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: auth behaviour
  # ---------------------------------------------------------------------------

  describe "require_auth: true" do
    test "returns 401 when no Authorization header is present" do
      conn =
        call(RequireAuthRouter, :get, "/xrpc/com.example.authed", xrpc_aud: "did:web:example.com")

      assert conn.status == 401
      body = json_body(conn)
      assert body["error"] == "AuthRequired"
    end

    test "returns 401 when Authorization header is malformed" do
      conn =
        call(RequireAuthRouter, :get, "/xrpc/com.example.authed",
          headers: [{"authorization", "NotBearer bad"}],
          xrpc_aud: "did:web:example.com"
        )

      assert conn.status == 401
      body = json_body(conn)
      assert body["error"] == "AuthRequired"
    end

    test "halts and does not run the block when auth fails" do
      conn =
        call(RequireAuthRouter, :get, "/xrpc/com.example.authed", xrpc_aud: "did:web:example.com")

      assert conn.halted
    end
  end

  describe "soft auth (require_auth: false, default)" do
    test "does not assign :current_jwt when no Authorization header" do
      conn =
        call(RequireAuthRouter, :get, "/xrpc/com.example.softAuth",
          xrpc_aud: "did:web:example.com"
        )

      assert conn.status == 200
      assert conn.resp_body == "no-jwt"
    end

    test "does not halt when no Authorization header" do
      conn =
        call(RequireAuthRouter, :get, "/xrpc/com.example.softAuth",
          xrpc_aud: "did:web:example.com"
        )

      refute conn.halted
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: AudPlug
  # ---------------------------------------------------------------------------

  describe "Atex.XRPC.Router.AudPlug" do
    test "raises at runtime when :service_did is not configured" do
      original = Application.get_env(:atex, :service_did)

      try do
        Application.delete_env(:atex, :service_did)

        assert_raise RuntimeError, ~r/:service_did is not configured/, fn ->
          conn(:get, "/")
          |> Atex.XRPC.Router.AudPlug.call([])
        end
      after
        if original do
          Application.put_env(:atex, :service_did, original)
        end
      end
    end

    test "puts :service_did into conn.private[:xrpc_aud]" do
      original = Application.get_env(:atex, :service_did)

      try do
        Application.put_env(:atex, :service_did, "did:web:test.example")

        conn =
          conn(:get, "/")
          |> Atex.XRPC.Router.AudPlug.call([])

        assert conn.private[:xrpc_aud] == "did:web:test.example"
      after
        if original do
          Application.put_env(:atex, :service_did, original)
        else
          Application.delete_env(:atex, :service_did)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: compile-time NSID validation
  # ---------------------------------------------------------------------------

  describe "invalid NSID string" do
    test "raises CompileError at macro expansion" do
      assert_raise CompileError, ~r/invalid NSID/, fn ->
        Code.compile_string("""
        defmodule BadNSIDRouter do
          use Plug.Router
          use Atex.XRPC.Router, plug_aud: false
          plug :match
          plug :dispatch
          query "not-a-valid-nsid" do
            send_resp(conn, 200, "")
          end
        end
        """)
      end
    end
  end

  describe "module without id/0" do
    test "raises CompileError at macro expansion" do
      assert_raise CompileError, ~r/does not define id\/0/, fn ->
        Code.compile_string("""
        defmodule NoIdModule do
          def something, do: :ok
        end

        defmodule BadModuleRouter do
          use Plug.Router
          use Atex.XRPC.Router, plug_aud: false
          plug :match
          plug :dispatch
          query NoIdModule do
            send_resp(conn, 200, "")
          end
        end
        """)
      end
    end
  end
end
