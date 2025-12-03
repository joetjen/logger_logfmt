# Quickstart Guide

Get started with LoggerLogfmt in under 5 minutes.

## Installation

Add LoggerLogfmt to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:logger_logfmt, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Configuration

Configure Logger to use the logfmt formatter in `config/config.exs`:

```elixir
config :logger, :console,
  format: {Logger.Backends.Logfmt, :format},
  metadata: [:request_id, :user_id]
```

## Basic Usage

```elixir
require Logger

# Simple log message
Logger.info("User logged in")
# Output: timestamp="2024-01-15 10:30:45.123" level=info message="User logged in"

# With metadata
Logger.info("Payment processed", amount: 99.99, currency: "USD")
# Output: timestamp="2024-01-15 10:30:45.123" level=info message="Payment processed" amount=99.99 currency=USD
```

## Common Configuration

### Customize Format Fields

```elixir
config :logger, :logfmt,
  format: [:timestamp, :level, :message, :metadata]
```

Available fields: `:timestamp`, `:level`, `:message`, `:domain`, `:node`, `:pid`, `:metadata`, `:file`, `:line`

### Metadata Filtering

```elixir
# Whitelist mode - only include specified keys
config :logger, :logfmt,
  metadata: [:request_id, :user_id],
  mode: :whitelist

# Blacklist mode - include all except specified keys
config :logger, :logfmt,
  metadata: [:password, :credit_card],
  mode: :blacklist
```

### Timestamp Format

```elixir
config :logger, :logfmt,
  timestamp_format: :iso8601  # or :elixir, :epoch_time
```

Formats:

- `:elixir` - `"2024-01-15 10:30:45.123"` (default)
- `:iso8601` - `"2024-01-15T10:30:45.123"`
- `:epoch_time` - Unix timestamp in seconds

## Features

- **Human-readable and machine-parseable** - Easy to read and grep
- **Automatic quoting** - Values with spaces are quoted
- **Nested maps** - Supported with dot notation (`user.name=Alice`)
- **Zero dependencies** - Pure Elixir implementation

## Next Steps

- **[USAGE_GUIDE.md](USAGE_GUIDE.md)** - Comprehensive feature documentation
- **[EXAMPLES.md](EXAMPLES.md)** - Complete runnable examples
- **[README.md](README.md)** - Project overview
