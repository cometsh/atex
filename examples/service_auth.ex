defmodule ServiceAuthExample do
  require Logger
  use Plug.Router

  plug :match
  plug :dispatch

  @did_doc JSON.encode!(%{
             "@context" => [
               "https://www.w3.org/ns/did/v1",
               "https://w3id.org/security/multikey/v1"
             ],
             "id" => "did:web:setsuna.prawn-galaxy.ts.net",
             "verificationMethod" => [
               %{
                 "id" => "did:web:setsuna.prawn-galaxy.ts.net#atproto",
                 "type" => "Multikey",
                 "controller" => "did:web:setsuna.prawn-galaxy.ts.net",
                 "publicKeyMultibase" => "zDnaeRBG9swcjKP6GjjQF7kqxP6JaJaVbvjTjJ1YbXnKWWLna"
               }
             ],
             "service" => [
               %{
                 "id" => "atex_test",
                 "type" => "AtexTest",
                 "serviceEndpoint" => "https://setsuna.prawn-galaxy.ts.net"
               }
             ]
           })

  get "/.well-known/did.json" do
    Logger.info("got did json")

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, @did_doc)
  end

  get "/xrpc/com.ovyerus.example" do
    IO.inspect(conn)

    conn
    |> send_resp(200, "")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
