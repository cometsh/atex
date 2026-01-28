# Changelog

All notable changes to atex will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The PLC directory used for identity resolution can now be configured. See
  `Atex.Config.IdentityResolve` for more information. (Thanks
  [@hexmani.ac](https://tangled.org/did:plc:5szlrh3xkfxxsuu4mo6oe6h7)!)
- Add an extra optional `opts` parameter to some `Atex.OAuth` functions, to
  allow for better integration with other ecosystems. (Thanks
  [@lekkice.moe](https://tangled.org/did:plc:dgzvruva4jbzqbta335jtvoz)!)

## [0.7.0] - 2026-01-07

### Breaking Changes

- `Atex.OAuth.Plug` now raises `Atex.OAuth.Error` exceptions instead of handling
  error situations internally. Applications should implement `Plug.ErrorHandler`
  to catch and gracefully handle them.
- `Atex.OAuth.Plug` now saves only the user's DID in the session instead of the
  entire OAuth session object. Applications must use `Atex.OAuth.SessionStore`
  to manage OAuth sessions.
- `Atex.XRPC.OAuthClient` has been overhauled to use `Atex.OAuth.SessionStore`
  for retrieving and managing OAuth sessions, making it easier to use with not
  needing to manually keep a Plug session in sync.

### Added

- `Atex.OAuth.SessionStore` behaviour and `Atex.OAuth.Session` struct for
  managing OAuth sessions with pluggable storage backends.
  - `Atex.OAuth.SessionStore.ETS` - in-memory session store implementation.
  - `Atex.OAuth.SessionStore.DETS` - persistent disk-based session store
    implementation.
- `Atex.OAuth.Plug` now requires a `:callback` option that is a MFA tuple
  (Module, Function, Args), denoting a callback function to be invoked by after
  a successful OAuth login. See [the OAuth example](./examples/oauth.ex) for a
  simple usage of this.
- `Atex.OAuth.Permission` module for creating
  [AT Protocol permission](https://atproto.com/specs/permission) strings for
  OAuth.
- `Atex.OAuth.Error` exception module for OAuth flow errors. Contains both a
  human-readable `message` string and a machine-readable `reason` atom for error
  handling.
- `Atex.OAuth.Cache` module provides TTL caching for OAuth authorization server
  metadata with a 1-hour default TTL to reduce load on third-party PDSs.
- `Atex.OAuth.get_authorization_server/2` and
  `Atex.OAuth.get_authorization_server_metadata/2` now support an optional
  `fresh` parameter to bypass the cache when needed.

### Changed

- `mix atex.lexicons` now adds `@moduledoc false` to generated modules to stop
  them from automatically cluttering documentation.
- `Atex.IdentityResolver.Cache.ETS` now uses ConCache instead of ETS directly,
  with a 1-hour TTL for cached identity information.

## [0.6.0] - 2025-11-25

### Breaking Changes

- `deflexicon` now converts all def names to be in snake_case instead of the
  casing as written the lexicon.

### Added

- `deflexicon` now emits structs for records, objects, queries, and procedures.
- `Atex.XRPC.get/3` and `Atex.XRPC.post/3` now support having a lexicon struct
  as the second argument instead of the method's name, making it easier to have
  properly checked XRPC calls.
- Add pre-transpiled modules for the core `com.atproto` lexicons.

## [0.5.0] - 2025-10-11

### Breaking Changes

- Remove `Atex.HTTP` and associated modules as the abstraction caused a bit too
  much complexities for how early atex is. It may come back in the future as
  something more fleshed out once we're more stable.
- Rename `Atex.XRPC.Client` to `Atex.XRPC.LoginClient`

### Added

- `Atex.OAuth` module with utilites for handling some OAuth functionality.
- `Atex.OAuth.Plug` module (if Plug is loaded) which provides a basic but
  complete OAuth flow, including storing the tokens in `Plug.Session`.
- `Atex.XRPC.Client` behaviour for implementing custom client variants.
- `Atex.XRPC` now supports using different client implementations.
- `Atex.XRPC.OAuthClient` to make XRPC calls on the behalf of a user who has
  authenticated with ATProto OAuth.

## [0.4.0] - 2025-08-27

### Added

- `Atex.Lexicon` module that provides the `deflexicon` macro, taking in a JSON
  Lexicon definition and converts it into a series of schemas for each
  definition within it.
- `mix atex.lexicons` for converting lexicon JSON files into modules using
  `deflexicon` easily.

## [0.3.0] - 2025-06-29

### Changed

- `Atex.XRPC.Adapter` renamed to `Atex.HTTP.Adapter`.

### Added

- `Atex.HTTP` module that delegates to the currently configured adapter.
- `Atex.HTTP.Response` struct to be returned by `Atex.HTTP.Adapter`.
- `Atex.IdentityResolver` module for resolving and validating an identity,
  either by DID or a handle.
  - Also has a pluggable cache (with a default ETS implementation) for keeping
    some data locally.

## [0.2.0] - 2025-06-09

### Added

- `Atex.TID` module for manipulating ATProto TIDs.
- `Atex.Base32Sortable` module for encoding/decoding numbers as
  `base32-sortable` strings.
- Basic XRPC client.

## [0.1.0] - 2025-06-07

Initial release.

[unreleased]: https://github.com/cometsh/atex/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/cometsh/atex/releases/tag/v0.7.0
[0.6.0]: https://github.com/cometsh/atex/releases/tag/v0.6.0
[0.5.0]: https://github.com/cometsh/atex/releases/tag/v0.5.0
[0.4.0]: https://github.com/cometsh/atex/releases/tag/v0.4.0
[0.3.0]: https://github.com/cometsh/atex/releases/tag/v0.3.0
[0.2.0]: https://github.com/cometsh/atex/releases/tag/v0.2.0
[0.1.0]: https://github.com/cometsh/atex/releases/tag/v0.1.0
