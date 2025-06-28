# Changelog

All notable changes to atex will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- ## [Unreleased] -->

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

[unreleased]: https://github.com/cometsh/atex/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/cometsh/atex/releases/tag/v0.3.0
[0.2.0]: https://github.com/cometsh/atex/releases/tag/v0.2.0
[0.1.0]: https://github.com/cometsh/atex/releases/tag/v0.1.0
