defmodule Atex.XRPC.Router.AudPlug do
  @moduledoc """
  Plug that populates `conn.private[:xrpc_aud]` from the `:service_did` app config.

  Injected automatically when using `Atex.XRPC.Router` (unless `plug_aud: false`
  is passed to `use`). Raises at runtime if `:service_did` is not configured,
  since auth validation requires a non-nil audience.

  ## Configuration

      config :atex, service_did: "did:web:my-service.example"
  """

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    aud =
      Atex.Config.service_did() ||
        raise """
        Atex.XRPC.Router.AudPlug: :service_did is not configured.
        Add the following to your config:

            config :atex, service_did: "did:web:my-service.example"

        Or disable automatic aud injection with:

            use Atex.XRPC.Router, plug_aud: false
        """

    put_private(conn, :xrpc_aud, aud)
  end
end
