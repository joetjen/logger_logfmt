# Contributing to LoggerLogfmt

Thanks for your interest in contributing! This document explains how to get set up and what's expected of a pull request.

## Getting Started

```bash
git clone https://github.com/joetjen/logger_logfmt.git
cd logger_logfmt
mix deps.get
mix test
```

The project has zero runtime dependencies; `credo`, `dialyxir`, and `ex_doc` are dev/test-only tooling. Keep it that way — new functionality should be implemented with the standard library.

## Before Opening a Pull Request

Run the full check suite and make sure everything is clean:

```bash
mix format
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test
mix docs
```

- `mix format` — code must be formatted; CI will reject unformatted diffs.
- `mix compile --warnings-as-errors` — no compiler warnings.
- `mix credo --strict` — no linter warnings.
- `mix dialyzer` — no type errors (first run builds a PLT and can take a while).
- `mix test` — all tests passing, including doctests.
- `mix docs` — documentation builds without warnings.

## Code Style

- Follow standard Elixir conventions and let `mix format` settle formatting disputes.
- Public functions require `@doc` and `@spec`.
- Modules require `@moduledoc`.
- Private functions should have a `@spec` and, where the intent isn't obvious from the name, a short `#` comment above the definition.
- Prefer pattern matching over conditional logic where it reads naturally.
- Predicate functions end in `?` rather than starting with `is_`.

## Tests

- Every public function should have test coverage, including edge cases (empty input, unicode, control characters, etc.).
- Add doctests for small, illustrative examples; use `test/**/*_test.exs` for exhaustive cases.
- Run a single file with `mix test test/path/to/file_test.exs`, or re-run only failures with `mix test --failed`.
- `mix test --cover` reports coverage if you want to check for gaps.

## Documentation

`README.md`, `QUICKSTART.md`, `USAGE_GUIDE.md`, and `EXAMPLES.md` are part of the published documentation (see `mix.exs`'s `docs/0`). If you change or add behavior, update the relevant doc(s) in the same PR — stale examples are worse than none.

## Commit Messages

This project loosely follows [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, etc.) for commit subjects — check `git log` for examples.

## Reporting Issues

Please open a GitHub issue with:

- The version of `logger_logfmt` and Elixir/OTP you're using.
- A minimal reproduction (config + code) if you're reporting a bug.
- Expected vs. actual output.

## License

By contributing, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
