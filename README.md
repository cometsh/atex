# atex

A set of utilities for working with the [AT Protocol](https://atproto.com) in
Elixir.

## Current Roadmap (in no particular order)

- [x] `at://` parsing and struct
- [x] TID codecs
- [x] XRPC client
- [x] DID & handle resolution service with a cache
- [ ] Structs with validation for the common lexicons
  - [ ] Probably codegen for doing this with other lexicons
- [ ] Extended XRPC client with support for validated inputs/outputs
- [ ] Oauth stuff

## Installation

Get atex from [hex.pm](https://hex.pm) by adding it to your `mix.exs`:

```elixir
def deps do
  [
    {:atex, "~> 0.3"}
  ]
end
```

Documentation can be found on HexDocs at https://hexdocs.pm/atex.

---

This project is licensed under the [MIT License](./LICENSE).
