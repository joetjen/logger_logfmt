# Usage Guide

A comprehensive guide to using LoggerLogfmt for structured logging in Elixir applications.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Format Options](#format-options)
- [Metadata Handling](#metadata-handling)
- [Timestamp Formats](#timestamp-formats)
- [Advanced Usage](#advanced-usage)
- [Best Practices](#best-practices)

## Quick Start

```elixir
# Add to mix.exs
{:logger_logfmt, "~> 0.1.0"}

# Configure in config/config.exs
config :logger, :console,
  format: {Logger.Backends.Logfmt, :format},
  metadata: :all

# Use in your code
require Logger
Logger.info("Application started")
```

## Configuration

### Basic Configuration

```elixir
# config/config.exs
config :logger, :console,
  format: {Logger.Backends.Logfmt, :format},
  metadata: [:request_id, :user_id, :module]
```

### Complete Configuration

```elixir
config :logger, :console,
  format: {Logger.Backends.Logfmt, :format},
  metadata: :all

config :logger, :logfmt,
  # Which fields to include in output
  format: [:timestamp, :level, :message, :metadata],

  # Metadata filtering
  metadata: [:request_id, :user_id],
  mode: :whitelist,

  # Timestamp configuration
  timestamp_format: :iso8601
```

### Environment-Specific Configuration

```elixir
# config/dev.exs
config :logger, :logfmt,
  format: [:timestamp, :level, :message, :file, :line, :metadata],
  mode: :blacklist,
  metadata: [:password]  # Exclude sensitive fields

# config/prod.exs
config :logger, :logfmt,
  format: [:timestamp, :level, :message, :node, :metadata],
  timestamp_format: :iso8601,
  mode: :whitelist,
  metadata: [:request_id, :user_id, :trace_id]
```

## Format Options

### Available Fields

| Field | Description | Example |
|-------|-------------|---------|
| `:timestamp` | Log event timestamp | `timestamp="2024-01-15 10:30:45.123"` |
| `:level` | Log level | `level=info` |
| `:message` | Log message | `message="User logged in"` |
| `:domain` | Logger domain | `domain=[:elixir]` |
| `:node` | Node name | `node="node1@host"` |
| `:pid` | Process ID | `pid="#PID<0.123.0>"` |
| `:metadata` | All filtered metadata | `user_id=123 request_id=abc` |
| `:file` | Source file path | `file="lib/my_app.ex"` |
| `:line` | Line number | `line=42` |

### Customizing Format

```elixir
# Minimal format
config :logger, :logfmt,
  format: [:level, :message]
# Output: level=info message="Hello"

# Development format with source location
config :logger, :logfmt,
  format: [:timestamp, :level, :message, :file, :line, :metadata]
# Output: timestamp="..." level=info message="Hello" file="lib/app.ex" line=25

# Production format with node info
config :logger, :logfmt,
  format: [:timestamp, :level, :node, :message, :metadata]
# Output: timestamp="..." level=info node="app@server1" message="Hello"
```

## Metadata Handling

### Whitelist Mode

Only include specified metadata keys:

```elixir
config :logger, :logfmt,
  metadata: [:request_id, :user_id, :trace_id],
  mode: :whitelist

# Usage
Logger.info("Request handled",
  request_id: "abc123",
  user_id: 42,
  internal_data: "ignored"  # Not included
)
# Output: ... request_id=abc123 user_id=42
```

### Blacklist Mode

Include all metadata except specified keys:

```elixir
config :logger, :logfmt,
  metadata: [:password, :token, :credit_card],
  mode: :blacklist

# Usage
Logger.info("User authenticated",
  user_id: 42,
  password: "secret",  # Excluded
  email: "user@example.com"
)
# Output: ... user_id=42 email="user@example.com"
```

### Dynamic Metadata

```elixir
# Set metadata for current process
Logger.metadata(request_id: "abc123")

# All subsequent logs include this metadata
Logger.info("Processing request")
# Output: ... request_id=abc123

Logger.info("Request complete")
# Output: ... request_id=abc123
```

### Nested Metadata

```elixir
Logger.info("User action",
  user: %{id: 123, name: "Alice"},
  action: "login"
)
# Output: ... user.id=123 user.name=Alice action=login
```

## Timestamp Formats

### Elixir Format (Default)

```elixir
config :logger, :logfmt,
  timestamp_format: :elixir

# Output: timestamp="2024-01-15 10:30:45.123"
```

### ISO 8601 Format

```elixir
config :logger, :logfmt,
  timestamp_format: :iso8601

# Output: timestamp="2024-01-15T10:30:45.123Z"
```

### Unix Epoch Format

```elixir
config :logger, :logfmt,
  timestamp_format: :epoch_time

# Output: timestamp=1705315845
```

## Advanced Usage

### Log Level Formatting

```elixir
Logger.debug("Debug message")
# Output: ... level=debug ...

Logger.info("Info message")
# Output: ... level=info ...

Logger.warning("Warning message")
# Output: ... level=warning ...

Logger.error("Error message")
# Output: ... level=error ...
```

### Special Characters

Values with special characters are automatically quoted and escaped:

```elixir
Logger.info("User search", query: "hello world")
# Output: ... query="hello world"

Logger.info("Path accessed", path: "/api/users?name=John&age=30")
# Output: ... path="/api/users?name=John&age=30"

Logger.info("Quote test", message: "He said \"hello\"")
# Output: ... message="He said \"hello\""
```

### List Values

```elixir
Logger.info("Multiple items", tags: [:urgent, :important])
# Output: ... tags="[:urgent, :important]"
```

### Empty and Nil Values

```elixir
Logger.info("Test", value: nil, empty: "")
# Output: ... value="" empty=""
```

## Best Practices

### 1. Consistent Metadata Keys

```elixir
# Good - consistent naming
Logger.metadata(request_id: request_id, user_id: user_id)

# Avoid - inconsistent naming
Logger.metadata(reqId: req_id, userId: user_id)
```

### 2. Structured Error Logging

```elixir
# Good - structured error info
Logger.error("Database error",
  error_type: "connection_timeout",
  error_message: "Failed to connect",
  retry_count: 3
)

# Avoid - unstructured
Logger.error("Database error: connection_timeout, Failed to connect, 3 retries")
```

### 3. Request Context

```elixir
defmodule MyApp.RequestLogger do
  def with_context(conn, fun) do
    Logger.metadata(
      request_id: conn.assigns.request_id,
      user_id: conn.assigns[:current_user_id],
      path: conn.request_path,
      method: conn.method
    )

    result = fun.()

    Logger.metadata(
      request_id: nil,
      user_id: nil,
      path: nil,
      method: nil
    )

    result
  end
end
```

### 4. Performance Metrics

```elixir
def process_request(request) do
  start_time = System.monotonic_time(:millisecond)

  result = do_process(request)

  duration = System.monotonic_time(:millisecond) - start_time

  Logger.info("Request processed",
    duration_ms: duration,
    status: :success
  )

  result
end
```

### 5. Sensitive Data Protection

```elixir
# Configure blacklist for sensitive fields
config :logger, :logfmt,
  mode: :blacklist,
  metadata: [:password, :token, :api_key, :credit_card, :ssn]

# Or sanitize before logging
defp sanitize_user(user) do
  %{id: user.id, email: mask_email(user.email)}
end

Logger.info("User created", user: sanitize_user(user))
```

### 6. Log Levels Appropriately

```elixir
# Debug - detailed development info
Logger.debug("Cache lookup", key: key, hit: hit?)

# Info - normal operations
Logger.info("User logged in", user_id: user_id)

# Warning - unexpected but handled
Logger.warning("Rate limit approaching", current: count, limit: max)

# Error - failures requiring attention
Logger.error("Payment failed", order_id: order_id, error: reason)
```

---

For more examples, see [EXAMPLES.md](EXAMPLES.md) and the [README](README.md).
