# atex

An Elxir toolkit for the [AT Protocol](https://atproto.com).

## Feature map

- [ ] ATProto strings
  - [x] `at://` links
  - [x] TIDs
  - [ ] NSIDs
  - [ ] CIDs
- [x] Identity resolution with bi-directional validation and caching.
- [x] Macro and codegen for converting Lexicon definitions to runtime schemas and structs.
- [x] OAuth client
- [x] XRPC client
  - With integration for generated Lexicon structs!
- [ ] Repository reading and manipulation (MST & CAR)
- [ ] Service auth
- [ ] PLC client

Looking to use a data subscription service like the Firehose, [Jetstream](https://docs.bsky.app/blog/jetstream), or [Tap](https://github.com/bluesky-social/indigo/blob/main/cmd/tap/README.md)? Check out [Drinkup](https://tangled.org/comet.sh/drinkup)

## Installation

Get atex from [hex.pm](https://hex.pm) by adding it to your `mix.exs`:

```elixir
def deps do
  [
    {:atex, "~> 0.7"}
  ]
end
```

Documentation can be found on HexDocs at https://hexdocs.pm/atex.

---

This project is licensed under the [MIT License](./LICENSE).
