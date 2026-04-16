# atex

An Elixir toolkit for the [AT Protocol](https://atproto.com).

## Feature map

- [x] ATProto strings
  - [x] `at://` links
  - [x] TIDs
  - [x] NSIDs
- [x] Identity resolution with bi-directional validation and caching.
- [x] Macro and codegen for converting Lexicon definitions to runtime schemas
      and structs.
- [x] OAuth client
- [x] XRPC client
  - With integration for generated Lexicon structs!
- [x] Repository reading and manipulation
- [x] Service auth
- [x] PLC client
- [x] XRPC server router

Looking to use a data subscription service like the Firehose, [Jetstream], or
[Tap]? Check out [Drinkup].

[Jetstream]: https://docs.bsky.app/blog/jetstream
[Tap]: https://github.com/bluesky-social/indigo/blob/main/cmd/tap/README.md
[Drinkup]: https://tangled.org/comet.sh/drinkup

## Installation

Get atex from [hex.pm](https://hex.pm) by adding it to your `mix.exs`:

```elixir
def deps do
  [
    {:atex, "~> 0.9"}
  ]
end
```

Documentation can be found on HexDocs at https://hexdocs.pm/atex.

---

This project is licensed under the [MIT License](./LICENSE).
