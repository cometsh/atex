import Config

config :atex, Atex.OAuth,
  # base_url: "https://comet.sh/aaaa",
  base_url: "http://127.0.0.1:4000/oauth",
  is_localhost: true,
  scopes: ~w(transition:generic),
  private_key:
    "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgyIpxhuDm0i3mPkrk6UdX4Sd9Jsv6YtAmSTza+A2nArShRANCAAQLF1GLueOBZOVnKWfrcnoDOO9NSRqH2utmfGMz+Rce18MDB7Z6CwFWjEq2UFYNBI4MI5cMI0+m+UYAmj4OZm+m",
  key_id: "awooga"

config :atex, Atex.IdentityResolver,
  directory_url: "https://plc.directory"
