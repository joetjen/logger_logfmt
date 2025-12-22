# LoggerLogfmt

A logfmt formatter for Elixir's Logger that outputs structured logs in the logfmt format.

[![Hex.pm](https://img.shields.io/hexpm/v/eel.svg)](https://hex.pm/packages/logger_logfmt)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/logger_logfmt)

## Overview

LoggerLogfmt provides a simple, text-based structured logging format where each log line consists of key-value pairs. The format is both human-readable and machine-parseable, making it ideal for log aggregation and analysis.

**Example output:**

```
timestamp="2024-01-15 10:30:45.123" level=info message="User logged in" user_id=42 request_id=abc123
```

## Features

- 🎯 **Flexible Configuration** - Customize which fields appear in your logs
- 🔒 **Metadata Filtering** - Whitelist or blacklist sensitive metadata
- ⏱️ **Multiple Timestamp Formats** - Elixir, ISO8601, or Unix epoch
- 🔤 **Automatic Quoting** - Proper escaping of special characters
- 🗂️ **Nested Maps** - Support for nested structures with dot notation
- 🚀 **Zero Dependencies** - Pure Elixir implementation

## Installation

Add `logger_logfmt` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:logger_logfmt, "~> 0.1.0"}
  ]
end
```

## Configuration

### Basic Setup

Configure the formatter in your `config/config.exs`:

```elixir
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

The `:format` option accepts a list of atoms that determine which fields to include:

| Field | Description |
|-------|-------------|
| `:timestamp` | Log event timestamp |
| `:level` | Log level (debug, info, warn, error) |
| `:message` | Log message |
| `:domain` | Logger domain |
| `:node` | Node name |
| `:pid` | Process identifier |
| `:metadata` | Additional metadata |
| `:file` | Source file |
| `:line` | Line number |

**Example:**

```elixir
config :logger, :logfmt,
  format: [:timestamp, :level, :message, :metadata]
```

### Metadata Filtering

#### Whitelist Mode (Default)

Only specified metadata keys will be included:

```elixir
config :logger, :logfmt,
  metadata: [:request_id, :user_id, :application],
  mode: :whitelist
```

#### Blacklist Mode

All metadata except specified keys will be included:

```elixir
config :logger, :logfmt,
  metadata: [:password, :credit_card, :secret_token],
  mode: :blacklist
```

### Timestamp Formats

Configure the timestamp format for log entries:

```elixir
# Elixir format: "2024-01-15 10:30:45.123"
config :logger, :logfmt, timestamp_format: :elixir

# ISO8601 format (default): "2024-01-15T10:30:45.123"
config :logger, :logfmt, timestamp_format: :iso8601

# Unix epoch time: 1705318245
config :logger, :logfmt, timestamp_format: :epoch_time
```

### Metadata Timestamp Format

Configure how DateTime/NaiveDateTime values in metadata are formatted:

```elixir
# Unix epoch time (default): created_at=1705318245
config :logger, :logfmt, metadata_timestamp_format: :epoch_time

# ISO8601 format: created_at="2024-01-15T10:30:45.123456Z"
config :logger, :logfmt, metadata_timestamp_format: :iso8601

# Elixir format: created_at="2024-01-15 10:30:45.123456"
config :logger, :logfmt, metadata_timestamp_format: :elixir
```

When using `:epoch_time`, the time unit is auto-detected from the key suffix:

- `*_ms` → milliseconds
- `*_us` → microseconds
- `*_ns` → nanoseconds
- No suffix → seconds

### Custom Field Keys

Rename the keys used for standard fields:

```elixir
config :logger, :logfmt,
  timestamp_key: "ts",
  level_key: "severity",
  message_key: "msg",
  domain_key: "app_domain",
  node_key: "node_name",
  pid_key: "process",
  file_key: "source_file",
  line_key: "source_line"
```

## Usage Examples

### Basic Logging

```elixir
require Logger

Logger.info("Application started")
# Output: timestamp="2024-01-15 10:30:45.123" level=info message="Application started"

Logger.error("Database connection failed")
# Output: timestamp="2024-01-15 10:30:45.123" level=error message="Database connection failed"
```

### Logging with Metadata

```elixir
Logger.info("User action", user_id: 42, action: "login", ip: "192.168.1.1")
# Output: timestamp="2024-01-15 10:30:45.123" level=info message="User action" user_id=42 action=login ip=192.168.1.1

Logger.warn("High memory usage", memory_mb: 512.5, threshold_mb: 500)
# Output: timestamp="2024-01-15 10:30:45.123" level=warn message="High memory usage" memory_mb=512.5 threshold_mb=500
```

### Logging Nested Data

```elixir
user = %{name: "John", address: %{city: "Berlin", zip: "10115"}}
Logger.info("User registered", user: user)
# Output: timestamp="2024-01-15 10:30:45.123" level=info message="User registered" user.name=John user.address.city=Berlin user.address.zip=10115
```

### DateTime and NaiveDateTime Values

DateTime and NaiveDateTime values in metadata are automatically formatted based on the `metadata_timestamp_format` option (defaults to `:epoch_time`):

```elixir
Logger.info("Event occurred", created_at: DateTime.utc_now())
# Output: timestamp="..." level=info message="Event occurred" created_at=1701619200

# Time unit is auto-detected from key suffix:
Logger.info("Event", created_at_ms: DateTime.utc_now())  # milliseconds
Logger.info("Event", created_at_us: DateTime.utc_now())  # microseconds
Logger.info("Event", created_at_ns: DateTime.utc_now())  # nanoseconds
```

### Special Characters Handling

```elixir
Logger.info("Message with \"quotes\" and spaces", tag: "special=chars")
# Output: timestamp="2024-01-15 10:30:45.123" level=info message="Message with \"quotes\" and spaces" tag="special=chars"
```

## Integration Examples

### Phoenix Application

In your Phoenix app's `config/config.exs`:

```elixir
config :logger, :console,
  format: {Logger.Backends.Logfmt, :format},
  metadata: [:request_id, :user_id]

config :logger, :logfmt,
  format: [:timestamp, :level, :message, :metadata],
  metadata: [:request_id, :user_id, :method, :path],
  mode: :whitelist,
  timestamp_format: :iso8601
```

Add request metadata in your endpoint:

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  plug Plug.RequestId
  plug Plug.Logger

  plug :add_logger_metadata

  defp add_logger_metadata(conn, _opts) do
    Logger.metadata(
      request_id: Logger.metadata()[:request_id],
      method: conn.method,
      path: conn.request_path
    )
    conn
  end
end
```

### Production Logging

For production environments with log aggregation:

```elixir
# config/prod.exs
config :logger, :console,
  format: {Logger.Backends.Logfmt, :format},
  metadata: :all

config :logger, :logfmt,
  format: [:timestamp, :level, :message, :node, :pid, :metadata],
  timestamp_format: :iso8601,
  mode: :blacklist,
  metadata: [:gl, :mfa, :__sentry__, :ansi_color]
```

## API Documentation

Full API documentation is available at [HexDocs](https://hexdocs.pm/logger_logfmt).

### Main Modules

- **`Logger.Backends.Logfmt`** - Main formatter with configuration options
- **`Logger.Backends.Logfmt.Encoder`** - Handles encoding of different data types
- **`Logger.Backends.Logfmt.Quoter`** - Manages quoting and escaping

## Testing

Run the test suite:

```bash
cd libs/logger_logfmt
mix test
```

Run with coverage:

```bash
mix test --cover
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

Apache License 2.0 - See LICENSE file for details.
