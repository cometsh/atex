defmodule Atex.XRPC.Router do
  @moduledoc """
  Routing utilities for building ATProto XRPC server endpoints.

  Provides the `query/3` and `procedure/3` macros that expand to
  `Plug.Router.get/3` and `Plug.Router.post/3` respectively, with built-in
  handling for:

  - NSID-prefixed route paths (`/xrpc/<nsid>`)
  - Service auth validation via `Atex.ServiceAuth`
  - Query param and body validation for lexicon modules generated with `Atex.Lexicon.deflexicon/1`.

  ## Usage

      defmodule MyAPI do
        use Plug.Router
        use Atex.XRPC.Router

        plug :match
        plug :dispatch

        # Matches GET /xrpc/com.example.getProfile
        query "com.example.getProfile" do
          send_resp(conn, 200, "ok")
        end

        # Matches POST /xrpc/com.example.createPost, enforces auth
        procedure Com.Example.CreatePost, require_auth: true do
          # conn.assigns[:params] and conn.assigns[:body] are populated
          # when the lexicon module defines Params/Input submodules
          send_resp(conn, 200, "created")
        end
      end

  ## Authentication

  Authentication uses `Atex.ServiceAuth.validate_conn/2`. The audience (`aud`)
  is read from `conn.private[:xrpc_aud]`, which is populated automatically by
  `Atex.XRPC.Router.AudPlug` that reads `:service_did` from app config. To
  disable automatic plug injection:

      use Atex.XRPC.Router, plug_aud: false

  When `require_auth: true` is passed to a route macro, a missing or invalid
  token halts with a `401` response. Otherwise auth is attempted softly -
  on success the decoded JWT is placed at `conn.assigns[:current_jwt]`, on
  failure the conn is left untouched.

  ## Validation

  When a lexicon module atom is passed, the macro checks at compile time whether
  `<Module>.Params` and/or `<Module>.Input` exist. If they do, their
  `from_json/1` is called at request time:

  - Valid params → `conn.assigns[:params]`
  - Valid body   → `conn.assigns[:body]`
  - Either failing → halts with a `400` response
  """

  @doc false
  defmacro __using__(opts \\ []) do
    plug_aud = Keyword.get(opts, :plug_aud, true)

    quote do
      import Atex.XRPC.Router, only: [query: 2, query: 3, procedure: 2, procedure: 3]

      if unquote(plug_aud) do
        plug Atex.XRPC.Router.AudPlug
      end
    end
  end

  @doc """
  Defines a GET route for an XRPC query.

  The first argument is either:

  - A plain string NSID (e.g. `"com.example.getProfile"`) - validated at
    compile time.
  - A lexicon module atom (e.g. `Com.Example.GetProfile`) - the NSID is
    fetched from `module.id()` at compile time.

  ## Options

  - `:require_auth` - when `true`, requests without a valid service auth token
    are rejected with a `401`. Defaults to `false`.

  ## Assigns

  - `:current_jwt` - the decoded `JOSE.JWT` struct, set on successful auth.
  - `:params`      - validated params struct, set when the lexicon module
    defines a `Params` submodule.

  ## Examples

      query "com.example.getTimeline", require_auth: true do
        send_resp(conn, 200, "ok")
      end

      query Com.Example.GetTimeline do
        send_resp(conn, 200, "ok")
      end
  """
  defmacro query(nsid_or_module, opts \\ [], do: block) do
    {nsid, params_module} = resolve_nsid_and_submodule(nsid_or_module, :Params, __CALLER__)
    require_auth = Keyword.get(opts, :require_auth, false)
    path = "/xrpc/#{nsid}"

    auth_block = build_auth_block(nsid, require_auth)
    params_block = if params_module, do: build_params_block(params_module), else: []

    quote do
      get unquote(path) do
        var!(conn) = Plug.Conn.fetch_query_params(var!(conn))
        unquote_splicing(auth_block)
        unquote_splicing(params_block)

        if var!(conn).halted do
          var!(conn)
        else
          unquote(block)
        end
      end
    end
  end

  @doc """
  Defines a POST route for an XRPC procedure.

  The first argument is either:

  - A plain string NSID (e.g. `"com.example.createPost"`) - validated at
    compile time.
  - A lexicon module atom (e.g. `Com.Example.CreatePost`) - the NSID is
    fetched from `module.id()` at compile time.

  ## Options

  - `:require_auth` - when `true`, requests without a valid service auth token
    are rejected with a `401`. Defaults to `false`.

  ## Assigns

  - `:current_jwt` - the decoded `JOSE.JWT` struct, set on successful auth.
  - `:params`      - validated params struct, set when the lexicon module
    defines a `Params` submodule.
  - `:body`        - validated input struct, set when the lexicon module
    defines an `Input` submodule.

  ## Non-JSON payloads

  If a lexicon procedure defines an `input` with an encoding without an `object`
  schema, this will simply validate the incoming `Content-Type` header against the
  requested encoding. Nothing happens on success, you will need to read `conn`'s
  body as usual and do extra validation yourself, as clients may lie about their content.
  Wildcards are handled correctly as per the atproto documentation.

  ## Examples

      procedure "com.example.createPost", require_auth: true do
        send_resp(conn, 200, "created")
      end

      procedure Com.Example.CreatePost, require_auth: true do
        # conn.assigns[:body] contains the validated Input struct
        send_resp(conn, 200, "created")
      end
  """
  defmacro procedure(nsid_or_module, opts \\ [], do: block) do
    {nsid, input_module} = resolve_nsid_and_submodule(nsid_or_module, :Input, __CALLER__)
    {_nsid, params_module} = resolve_nsid_and_submodule(nsid_or_module, :Params, __CALLER__)
    raw_input_module = resolve_raw_input_module(nsid_or_module, input_module, __CALLER__)
    require_auth = Keyword.get(opts, :require_auth, false)
    path = "/xrpc/#{nsid}"

    auth_block = build_auth_block(nsid, require_auth)
    params_block = if params_module, do: build_params_block(params_module), else: []

    body_block =
      cond do
        input_module -> build_body_block(input_module)
        raw_input_module -> build_raw_body_block(raw_input_module)
        true -> []
      end

    quote do
      post unquote(path) do
        var!(conn) = Plug.Conn.fetch_query_params(var!(conn))
        unquote_splicing(auth_block)
        unquote_splicing(params_block)
        unquote_splicing(body_block)

        if var!(conn).halted do
          var!(conn)
        else
          unquote(block)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers (compile-time)
  # ---------------------------------------------------------------------------

  # Returns the root lexicon module if it represents a raw-input procedure
  # (i.e. it exports `content_type/0` but has no `Input` submodule with
  # `from_json/1`). Returns `nil` in all other cases, including when
  # `nsid_or_module` is a plain string NSID.
  @spec resolve_raw_input_module(term(), module() | nil, Macro.Env.t()) :: module() | nil
  defp resolve_raw_input_module(nsid_or_module, input_module, env) do
    with nil <- input_module,
         {:__aliases__, _, _} = ast <- nsid_or_module do
      module = Macro.expand(ast, env)

      if Code.ensure_loaded?(module) and function_exported?(module, :content_type, 0) do
        module
      end
    else
      _ -> nil
    end
  end

  # Returns {nsid_string, submodule_atom_or_nil}.
  # `submodule` is e.g. :Params or :Input.
  @spec resolve_nsid_and_submodule(term(), atom(), Macro.Env.t()) ::
          {String.t(), module() | nil}
  defp resolve_nsid_and_submodule(nsid_or_module, submodule_suffix, env) do
    case nsid_or_module do
      nsid when is_binary(nsid) ->
        unless Atex.NSID.match?(nsid) do
          raise CompileError,
            file: env.file,
            line: env.line,
            description: "invalid NSID: #{inspect(nsid)}"
        end

        {nsid, nil}

      {:__aliases__, _, _} = ast ->
        module = Macro.expand(ast, env)

        unless Code.ensure_loaded?(module) and function_exported?(module, :id, 0) do
          raise CompileError,
            file: env.file,
            line: env.line,
            description:
              "#{inspect(module)} does not define id/0 - " <>
                "only lexicon modules generated by deflexicon are supported"
        end

        nsid = module.id()

        unless Atex.NSID.match?(nsid) do
          raise CompileError,
            file: env.file,
            line: env.line,
            description: "#{inspect(module)}.id() returned an invalid NSID: #{inspect(nsid)}"
        end

        candidate = Module.concat(module, submodule_suffix)

        sub =
          if Code.ensure_loaded?(candidate) and function_exported?(candidate, :from_json, 1) do
            candidate
          end

        {nsid, sub}
    end
  end

  # Emits a list of quoted expressions that perform auth (soft + optional strict).
  # Uses var!(conn) to pierce macro hygiene and reference the `conn` variable
  # introduced by Plug.Router.get/post in the caller's context.
  @spec build_auth_block(String.t(), boolean()) :: [Macro.t()]
  defp build_auth_block(nsid, require_auth) do
    soft_auth =
      quote do
        var!(conn) =
          case Atex.ServiceAuth.validate_conn(var!(conn),
                 aud: var!(conn).private[:xrpc_aud],
                 lxm: unquote(nsid)
               ) do
            {:ok, jwt} -> Plug.Conn.assign(var!(conn), :current_jwt, jwt)
            _err -> var!(conn)
          end
      end

    strict_auth =
      if require_auth do
        quote do
          var!(conn) =
            if is_nil(var!(conn).assigns[:current_jwt]) do
              var!(conn)
              |> Plug.Conn.put_resp_content_type("application/json")
              |> Plug.Conn.send_resp(
                401,
                Jason.encode!(%{
                  "error" => "AuthRequired",
                  "message" => "Authentication required"
                })
              )
              |> Plug.Conn.halt()
            else
              var!(conn)
            end
        end
      end

    [soft_auth | List.wrap(strict_auth)]
  end

  # Emits a quoted expression that validates query params via `module.from_json/1`.
  # Skips if the conn is already halted by a previous step.
  @spec build_params_block(module()) :: [Macro.t()]
  defp build_params_block(params_module) do
    [
      quote do
        var!(conn) =
          if var!(conn).halted do
            var!(conn)
          else
            case unquote(params_module).from_json(var!(conn).query_params) do
              {:ok, params} ->
                Plug.Conn.assign(var!(conn), :params, params)

              {:error, reason} ->
                var!(conn)
                |> Plug.Conn.put_resp_content_type("application/json")
                |> Plug.Conn.send_resp(
                  400,
                  Jason.encode!(%{
                    "error" => "InvalidRequest",
                    "message" => "Invalid query parameters: #{inspect(reason)}"
                  })
                )
                |> Plug.Conn.halt()
            end
          end
      end
    ]
  end

  # Emits a quoted expression that validates the request body via `module.from_json/1`.
  # Skips if the conn is already halted by a previous step.
  @spec build_body_block(module()) :: [Macro.t()]
  defp build_body_block(input_module) do
    [
      quote do
        var!(conn) =
          if var!(conn).halted do
            var!(conn)
          else
            case unquote(input_module).from_json(var!(conn).body_params) do
              {:ok, body} ->
                Plug.Conn.assign(var!(conn), :body, body)

              {:error, reason} ->
                var!(conn)
                |> Plug.Conn.put_resp_content_type("application/json")
                |> Plug.Conn.send_resp(
                  400,
                  Jason.encode!(%{
                    "error" => "InvalidRequest",
                    "message" => "Invalid request body: #{inspect(reason)}"
                  })
                )
                |> Plug.Conn.halt()
            end
          end
      end
    ]
  end

  # Emits a quoted expression that validates the incoming Content-Type header
  # against the MIME type declared in the lexicon for a raw (non-JSON) input
  # procedure. On success, the raw body is placed at `conn.assigns[:body]`.
  # Skips if the conn is already halted by a previous step.
  @spec build_raw_body_block(module()) :: [Macro.t()]
  defp build_raw_body_block(raw_module) do
    [
      quote do
        var!(conn) =
          if var!(conn).halted do
            var!(conn)
          else
            declared = unquote(raw_module).content_type()

            parsed_content_type =
              var!(conn)
              |> Plug.Conn.get_req_header("content-type")
              |> List.first("")
              |> Plug.Conn.Utils.content_type()

            with {:ok, type, subtype, _params} <- parsed_content_type,
                 actual <- "#{type}/#{subtype}",
                 true <-
                   declared == "*/*" or actual == declared or
                     (String.ends_with?(declared, "/*") and
                        String.starts_with?(actual, String.trim_trailing(declared, "*"))) do
              var!(conn)
            else
              var!(conn)
              |> Plug.Conn.put_resp_content_type("application/json")
              |> Plug.Conn.send_resp(
                415,
                JSON.encode!(%{
                  "error" => "InvalidRequest",
                  message: "Unsupported media type: expected #{declared}"
                })
              )
            end
          end
      end
    ]
  end
end
