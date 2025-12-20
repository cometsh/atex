defmodule ExampleOAuthPlug do
  require Logger
  use Plug.Router
  alias Atex.OAuth
  alias Atex.XRPC

  plug :put_secret_key_base

  plug Plug.Session,
    store: :cookie,
    key: "atex-oauth",
    signing_salt: "signing-salt"

  plug :match
  plug :dispatch

  forward "/oauth", to: Atex.OAuth.Plug, init_opts: [callback: {__MODULE__, :oauth_callback, []}]

  def oauth_callback(conn) do
    IO.inspect(conn, label: "callback from oauth!")

    conn
    |> put_resp_header("Location", "/whoami")
    |> resp(307, "")
    |> send_resp()
  end

  get "/whoami" do
    conn = fetch_session(conn)

    case XRPC.OAuthClient.from_conn(conn) do
      {:ok, client} ->
        send_resp(conn, 200, "hello #{client.did}")

      :error ->
        send_resp(conn, 401, "Unauthorized")
    end
  end

  post "/create-post" do
    conn = fetch_session(conn)

    with {:ok, client} <- XRPC.OAuthClient.from_conn(conn),
         {:ok, response, client} <-
           XRPC.post(client, %Com.Atproto.Repo.CreateRecord{
             input: %Com.Atproto.Repo.CreateRecord.Input{
               repo: client.did,
               collection: "app.bsky.feed.post",
               rkey: Atex.TID.now() |> to_string(),
               record: %{
                 "$type": "app.bsky.feed.post",
                 text: "Hello world from atex!",
                 createdAt: NaiveDateTime.to_iso8601(NaiveDateTime.utc_now())
               }
             }
           }) do
      IO.inspect(response, label: "output")

      conn
      |> XRPC.OAuthClient.update_conn(client)
      |> send_resp(200, response.uri)
    else
      :error ->
        send_resp(conn, 401, "Unauthorized")

      err ->
        IO.inspect(err, label: "xrpc failed")
        send_resp(conn, 500, "xrpc failed")
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  def put_secret_key_base(conn, _) do
    put_in(
      conn.secret_key_base,
      # Don't use this in production
      "5ef1078e1617463a3eb3feb9b152e76587a75a6809e0485a125b6bb7ae468f086680771f700d77ff61dfdc8d8ee8a5c7848024a41cf5ad4b6eb3115f74ce6e46"
    )
  end
end
