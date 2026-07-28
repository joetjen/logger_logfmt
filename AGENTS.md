# AI Agents Guidelines for LoggerLogfmt

LoggerLogfmt is an Elixir library that provides a logfmt formatter for Elixir's Logger.

## Project Structure

- `lib/` - Source code
  - `logger_logfmt.ex` - Main module with documentation
  - `logger/backends/logfmt.ex` - Core formatter implementation
  - `logger/backends/logfmt/encoder.ex` - Key-value pair encoder
  - `logger/backends/logfmt/quoter.ex` - Quoting and escaping logic
- `test/` - Test files
- `doc/` - Generated documentation
- `mix.exs` - Project configuration
- `README.md` - Overview (always keep up to date)
- `QUICKSTART.md` - Quick start (always keep up to date)
- `USAGE_GUIDE.md` - Detailed usage documentation (always keep up to date)
- `EXAMPLES.md` - Code examples (always keep up to date)
- `CONTRIBUTING.md` - Contributor setup and PR checklist
- `CHANGELOG.md` - Keep a Changelog-formatted release history (update on every user-visible change)

## Library Overview

LoggerLogfmt formats log messages in the logfmt format - a structured logging format that outputs key-value pairs that are both human-readable and machine-parseable.

### Key Features

- **Flexible Configuration**: Customize which fields appear in logs
- **Metadata Filtering**: Whitelist or blacklist metadata fields
- **Multiple Timestamp Formats**: Elixir, ISO8601, and Unix epoch formats
- **Automatic Quoting**: Values with special characters are properly quoted and escaped
- **Nested Maps**: Supports nested structures with dot notation
- **Zero Dependencies**: Pure Elixir implementation

### Basic Usage

```elixir
# Configure in config.exs
config :logger, :console,
  format: {Logger.Backends.Logfmt, :format},
  metadata: [:request_id, :user_id]

config :logger, :logfmt,
  format: [:timestamp, :level, :message, :metadata],
  metadata: [:application, :request_id],
  mode: :whitelist,
  timestamp_format: :iso8601
```

### Format Options

The `:format` option accepts these atoms:

- `:timestamp` - Log event timestamp
- `:level` - Log level (debug, info, warn, error)
- `:message` - Log message
- `:domain` - Logger domain
- `:node` - Node name
- `:pid` - Process identifier
- `:metadata` - Additional metadata
- `:file` - Source file
- `:line` - Line number

### Metadata Modes

- **Whitelist mode** (default): Only specified keys are included
- **Blacklist mode**: All metadata except specified keys are included

### Timestamp Formats

- `:elixir` - "2024-01-15 10:30:45.123" (default)
- `:iso8601` - "2024-01-15T10:30:45.123"
- `:epoch_time` - Unix timestamp in seconds

## Development Guidelines

### Before Committing

- Run `mix format` to format code
- Run `mix compile --warnings-as-errors` to ensure no compilation warnings
- Run `mix credo --strict` for static analysis and fix all warnings
- Run `mix dialyzer` for type checking
- Run `mix test` to ensure all tests pass with no warnings
- Run `mix docs` to verify documentation generates without warnings
- Ensure `README.md`, `QUICKSTART.md`, `USAGE_GUIDE.md`, and `EXAMPLES.md` are updated

### Code Style

- Follow standard Elixir conventions
- Use `@moduledoc` and `@doc` for all public modules and functions
- Use `@spec` type specifications for public functions
- Predicate function names should end in `?` (not start with `is_`)
- Use pattern matching over conditional logic where possible
- Fix all compiler warnings - do not commit code with warnings
- Fix all linter warnings from `mix credo --strict`

### Testing

- Write tests for all public functions
- Use ExUnit and standard Elixir testing patterns
- Run specific test files with `mix test test/path_test.exs`
- Run failed tests with `mix test --failed`
- Use `mix test --cover` for coverage reports
- Tests must run without warnings

### Documentation

- Keep `README.md` concise with quick start examples
- Put detailed documentation in `USAGE_GUIDE.md`
- Put code examples in `EXAMPLES.md`
- Use proper Markdown formatting
- Include `## Example` sections in `@doc` strings
- **Always update documentation when changing functionality**

## Module Architecture

### `Logger.Backends.Logfmt`

Main formatter module. The `format/5` function is the entry point:

```elixir
def format(level, message, timestamp, metadata, opts \\ [])
```

### `Logger.Backends.Logfmt.Encoder`

Handles encoding of different Elixir types to logfmt key-value strings, dispatched by `encode/3` clause in this order:

1. Logger's raw timestamp tuple (`{{y, m, d}, {h, mi, s, ms}}`) and `DateTime`/`NaiveDateTime` - formatted per `:timestamp_format` / `:metadata_timestamp_format`
2. Integers, floats, booleans, `nil`, atoms, binaries - encoded directly (atoms via `inspect/2`)
3. Structs - `to_string/1` if they implement `String.Chars`, otherwise encoded as a map
4. Maps - nested dot notation, `__struct__` stripped
5. Anything else (tuples, PIDs, references, lists, functions, ...) - `to_string/1` if `String.Chars` is implemented *and* doesn't raise (e.g. a charlist), otherwise `inspect/2`

All values are passed through `Logger.Backends.Logfmt.Quoter` before being written.

### `Logger.Backends.Logfmt.Quoter`

Handles quoting logic:

- Determines when values need quoting (spaces, special characters)
- Escapes quotes and backslashes within quoted values
- Handles multi-line values

## Best Practices for This Library

### When Adding New Format Options

1. Add the new option to `@default_format` if it should be included by default
2. Create a new `encode/6` clause for the option
3. Add configuration key defaults (e.g., `@default_*_key`)
4. Update documentation in all relevant files
5. Add tests for the new option

### When Modifying Encoding

1. Update `Logger.Backends.Logfmt.Encoder` for type handling
2. Update `Logger.Backends.Logfmt.Quoter` if quoting logic changes
3. Ensure backward compatibility with existing configurations
4. Test with various edge cases (special characters, unicode, empty values)

### Logging Best Practices (for users of this library)

```elixir
# CORRECT: Use metadata for structured data
Logger.info("User created", user_id: user.id, email: user.email)
Logger.debug("Request completed", duration_ms: duration, path: path)

# INCORRECT: String interpolation
Logger.info("User #{user.id} created with email #{user.email}")
Logger.debug("Request to #{path} completed in #{duration}ms")
```

## Elixir Guidelines

### Variables and Data

- Elixir variables are immutable but can be rebound
- Lists do not support index-based access via `[]` syntax - use `Enum.at/2`
- Never use `String.to_atom/1` on user input (memory leak risk)
- Use `Map.get/3` with default for optional map access

### Block Expressions

For `if`, `case`, `cond`, etc., bind the result to use it:

```elixir
# VALID: bind the result
result =
  if condition do
    encode_value(value)
  else
    ""
  end

# INVALID: rebinding inside doesn't work
if condition do
  result = encode_value(value)
end
```

### Dependencies

- This library has zero runtime dependencies
- Keep it that way - use only standard library functions
- Dev dependencies (credo, dialyxir, ex_doc) are acceptable

## Mix Guidelines

- Use `mix help task_name` to read task documentation
- Use `mix deps.get` to fetch dependencies
- Use `mix deps.compile` to compile dependencies
- Avoid `mix deps.clean --all` unless absolutely necessary
