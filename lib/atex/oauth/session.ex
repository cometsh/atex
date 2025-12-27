defmodule Atex.OAuth.Session do
  @moduledoc """
  Struct representing an active OAuth session for an AT Protocol user.

  Contains all the necessary credentials and metadata to make authenticated
  requests to a user's PDS using OAuth with DPoP.

  ## Fields

  - `:iss` - Authorization server issuer URL
  - `:aud` - PDS endpoint URL (audience)
  - `:sub` - User's DID (subject), used as the session key
  - `:access_token` - OAuth access token for authenticating requests
  - `:refresh_token` - OAuth refresh token for obtaining new access tokens
  - `:expires_at` - When the current access token expires (NaiveDateTime in UTC)
  - `:dpop_key` - DPoP signing key (Demonstrating Proof-of-Possession)
  - `:dpop_nonce` - Server-provided nonce for DPoP proofs (optional, updated per-request)

  ## Usage

  Sessions are typically created during the OAuth flow and stored in a `SessionStore`.
  They should not be created manually in most cases.

      session = %Atex.OAuth.Session{
        iss: "https://bsky.social",
        aud: "https://puffball.us-east.host.bsky.network",
        sub: "did:plc:abc123",
        access_token: "...",
        refresh_token: "...",
        expires_at: ~N[2026-01-04 12:00:00],
        dpop_key: dpop_key,
        dpop_nonce: "server-nonce"
      }
  """
  use TypedStruct

  typedstruct enforce: true do
    # Authz server issuer
    field :iss, String.t()
    # PDS endpoint
    field :aud, String.t()
    # User's DID
    field :sub, String.t()
    field :access_token, String.t()
    field :refresh_token, String.t()
    field :expires_at, NaiveDateTime.t()
    field :dpop_key, JOSE.JWK.t()
    field :dpop_nonce, String.t() | nil, enforce: false
  end
end
