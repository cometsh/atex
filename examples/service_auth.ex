defmodule ServiceAuthExample do
  require Logger
  use Plug.Router
  use Atex.XRPC.Router

  plug :match
  plug :dispatch

  @did_doc %Atex.DID.Document{
             "@context": [
               "https://www.w3.org/ns/did/v1",
               "https://w3id.org/security/multikey/v1"
             ],
             id: "did:web:setsuna.prawn-galaxy.ts.net",
             verification_method: [
               %Atex.DID.Document.VerificationMethod{
                 id: "did:web:setsuna.prawn-galaxy.ts.net#atproto",
                 type: "Multikey",
                 controller: "did:web:setsuna.prawn-galaxy.ts.net",
                 public_key_jwk: Atex.Config.OAuth.get_key()
               }
             ],
             service: [
               %Atex.DID.Document.Service{
                 id: "atex_test",
                 type: "AtexTest",
                 service_endpoint: "https://setsuna.prawn-galaxy.ts.net"
               }
             ]
           }
           |> JSON.encode!()

  get "/.well-known/did.json" do
    Logger.info("got did json")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, @did_doc)
  end

  query "com.example.test" do
    IO.inspect(conn)
    conn |> send_resp(200, "test")
  end

  # See `./service_auth` for module & lexicon definitions.
  query Com.Example.GetProfile do
    IO.inspect(conn.assigns, label: "getProfile")
    conn |> send_resp(200, "test")
  end

  # TODO: why did body not validate
  procedure Com.Example.CreatePost, require_auth: true do
    IO.inspect(conn.assigns, label: "createPost")
    conn |> send_resp(200, "test")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
