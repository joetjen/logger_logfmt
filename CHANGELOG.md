# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-07-28

### Changed

- **Breaking:** the project is now licensed under the MIT License instead of Apache-2.0.
- Struct values are now encoded via `to_string/1` when they implement the `String.Chars`
  protocol, and as nested maps otherwise, replacing a hardcoded check for a single
  internal struct type.
- Any other value not otherwise handled is now encoded via `to_string/1` when it
  implements `String.Chars`, falling back to `inspect/2` only when no implementation
  exists or applying it fails (e.g. lists that aren't valid chardata).

### Added

- `CONTRIBUTING.md` with contributor setup instructions and the pre-PR checklist.
- `@spec` on every public and private function, plus explanatory comments on
  non-obvious private helpers.

### Fixed

- Correct the source URL in `mix.exs`.
- Ignore all tarballs in `.gitignore` instead of a single pattern.
- Add a license badge to the README.
- Escape the delete character (`0x7F`) when quoting values; it was previously quoted
  but left unescaped, unlike every other control character.
- Fixed broken/stale documentation: wrong package name in the Hex.pm and license
  badges, a `~> 0.1.0` version placeholder left over from before the 1.0 release,
  a `Logger.warn/2` example (removed since Elixir 1.15), and a leftover
  `cd libs/logger_logfmt` step in the README's test instructions.
- Documented struct/`String.Chars` handling in the README and USAGE_GUIDE, which
  had no mention of it.

### Simplified

- Collapsed 32 near-identical `escape/2` clauses for control characters `0x00`-`0x1F`
  into a single guarded clause that computes the `\uXXXX` escape.
- Extracted the repeated delimiter/prefix assembly in `Encoder.encode/3` into a
  shared `build/3` helper.

## [1.0.1] - 2025-12-10

### Fixed

- Correct the package version and source URL in `mix.exs`.

## [1.0.0] - 2025-12-03

### Added

- Logfmt formatter for Elixir's `Logger`, outputting structured logs in the logfmt format.
- Quoting and escaping module for handling special characters in log values.
- Configurable timestamp formats: Elixir, ISO8601, and Unix epoch.
- Metadata filtering via whitelist and blacklist modes.
- Apache License 2.0.
- Documentation covering installation, configuration, and usage (README, QUICKSTART, USAGE_GUIDE, EXAMPLES).
