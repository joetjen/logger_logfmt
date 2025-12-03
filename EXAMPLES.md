# Examples

This document provides comprehensive, runnable examples demonstrating how to use LoggerLogfmt for structured logging in Elixir applications.

## Table of Contents

- [Basic Logging](#basic-logging)
- [Configuration Examples](#configuration-examples)
- [Phoenix Integration](#phoenix-integration)
- [Real-World Patterns](#real-world-patterns)
- [Log Analysis](#log-analysis)

## Basic Logging

### Simple Messages

```elixir
defmodule BasicLogging do
  require Logger

  def run do
    # Simple log message
    Logger.info("Application started")
    # Output: timestamp="2024-01-15 10:30:45.123" level=info message="Application started"

    # With inline metadata
    Logger.info("User logged in", user_id: 123)
    # Output: timestamp="..." level=info message="User logged in" user_id=123

    # Multiple metadata fields
    Logger.info("Order placed",
      order_id: "ORD-001",
      amount: 99.99,
      currency: "USD"
    )
    # Output: timestamp="..." level=info message="Order placed" order_id=ORD-001 amount=99.99 currency=USD
  end
end

BasicLogging.run()
```

### Log Levels

```elixir
defmodule LogLevelsExample do
  require Logger

  def run do
    Logger.debug("Detailed debugging info", data: %{foo: "bar"})
    # Output: ... level=debug message="Detailed debugging info" data.foo=bar

    Logger.info("Normal operation completed", duration_ms: 45)
    # Output: ... level=info message="Normal operation completed" duration_ms=45

    Logger.warning("Potential issue detected", threshold: 80, current: 85)
    # Output: ... level=warning message="Potential issue detected" threshold=80 current=85

    Logger.error("Operation failed", error: "timeout", retries: 3)
    # Output: ... level=error message="Operation failed" error=timeout retries=3
  end
end

LogLevelsExample.run()
```

### Process Metadata

```elixir
defmodule ProcessMetadataExample do
  require Logger

  def run do
    # Set metadata for current process
    Logger.metadata(
      request_id: "req-abc123",
      user_id: 42
    )

    # All logs now include this metadata
    Logger.info("Starting request")
    # Output: ... message="Starting request" request_id=req-abc123 user_id=42

    Logger.info("Processing data")
    # Output: ... message="Processing data" request_id=req-abc123 user_id=42

    # Add more metadata
    Logger.metadata(step: "validation")
    Logger.info("Validating input")
    # Output: ... message="Validating input" request_id=req-abc123 user_id=42 step=validation

    # Clear metadata
    Logger.reset_metadata()
    Logger.info("Cleanup complete")
    # Output: ... message="Cleanup complete"
  end
end

ProcessMetadataExample.run()
```

## Configuration Examples

### Development Configuration

```elixir
# config/dev.exs
import Config

config :logger, :console,
  format: {Logger.Backends.Logfmt, :format},
  metadata: :all,
  level: :debug

config :logger, :logfmt,
  format: [:timestamp, :level, :message, :file, :line, :metadata],
  mode: :blacklist,
  metadata: [:password, :token],  # Exclude sensitive fields
  timestamp_format: :elixir

# Example output:
# timestamp="2024-01-15 10:30:45.123" level=debug message="Debug info" file="lib/app.ex" line=42 user_id=123
```

### Production Configuration

```elixir
# config/prod.exs
import Config

config :logger, :console,
  format: {Logger.Backends.Logfmt, :format},
  metadata: :all,
  level: :info

config :logger, :logfmt,
  format: [:timestamp, :level, :node, :message, :metadata],
  mode: :whitelist,
  metadata: [:request_id, :user_id, :trace_id, :span_id],
  timestamp_format: :iso8601

# Example output:
# timestamp="2024-01-15T10:30:45.123Z" level=info node="app@prod-server-1" message="Request handled" request_id=abc123 user_id=42
```

### Minimal Configuration

```elixir
# For simple applications
config :logger, :console,
  format: {Logger.Backends.Logfmt, :format},
  metadata: [:application, :module]

config :logger, :logfmt,
  format: [:timestamp, :level, :message, :metadata]
```

## Phoenix Integration

### Plug for Request Logging

```elixir
defmodule MyAppWeb.RequestLogger do
  @behaviour Plug

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time(:millisecond)
    request_id = get_or_generate_request_id(conn)

    # Set logger metadata
    Logger.metadata(
      request_id: request_id,
      path: conn.request_path,
      method: conn.method,
      remote_ip: format_ip(conn.remote_ip)
    )

    Logger.info("Request started")

    # Register callback for when response is sent
    Plug.Conn.register_before_send(conn, fn conn ->
      duration = System.monotonic_time(:millisecond) - start_time

      Logger.info("Request completed",
        status: conn.status,
        duration_ms: duration
      )

      conn
    end)
  end

  defp get_or_generate_request_id(conn) do
    case Plug.Conn.get_req_header(conn, "x-request-id") do
      [id | _] -> id
      [] -> generate_request_id()
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_ip(ip), do: to_string(ip)
end

# In your router or endpoint:
plug MyAppWeb.RequestLogger
```

### Controller Logging

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  require Logger

  def create(conn, params) do
    Logger.info("Creating user", email: params["email"])

    case Users.create_user(params) do
      {:ok, user} ->
        Logger.info("User created successfully", user_id: user.id)
        json(conn, %{id: user.id})

      {:error, changeset} ->
        Logger.warning("User creation failed",
          errors: format_errors(changeset)
        )
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
```

### LiveView Logging

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view
  require Logger

  def mount(_params, session, socket) do
    Logger.metadata(
      live_view: "DashboardLive",
      user_id: session["user_id"]
    )

    Logger.info("LiveView mounted")
    {:ok, socket}
  end

  def handle_event("refresh", _params, socket) do
    Logger.info("Dashboard refresh requested")
    {:noreply, assign(socket, data: fetch_data())}
  end

  def handle_info({:update, data}, socket) do
    Logger.debug("Received update", data_count: length(data))
    {:noreply, assign(socket, data: data)}
  end
end
```

### DateTime and NaiveDateTime Values

```elixir
defmodule DateTimeExample do
  require Logger

  def run do
    now = DateTime.utc_now()
    naive_now = NaiveDateTime.utc_now()

    # DateTime values are formatted based on metadata_timestamp_format
    # Default is :epoch_time (Unix timestamp in seconds)
    Logger.info("Event occurred", created_at: now)
    # Output: ... created_at=1701619200

    # Time unit auto-detected from key suffix
    Logger.info("Timing data",
      started_at: now,           # seconds
      started_at_ms: now,        # milliseconds
      started_at_us: now,        # microseconds
      started_at_ns: now         # nanoseconds
    )
    # Output: ... started_at=1701619200 started_at_ms=1701619200123 started_at_us=1701619200123456 started_at_ns=1701619200123456000

    # NaiveDateTime works the same way
    Logger.info("Naive timestamp", timestamp: naive_now)
    # Output: ... timestamp=1701619200
  end
end

DateTimeExample.run()
```

## Real-World Patterns

### Service Layer Logging

```elixir
defmodule MyApp.OrderService do
  require Logger

  def create_order(user_id, items) do
    Logger.metadata(user_id: user_id, operation: "create_order")
    Logger.info("Creating order", item_count: length(items))

    with {:ok, order} <- build_order(user_id, items),
         {:ok, order} <- validate_order(order),
         {:ok, order} <- persist_order(order),
         {:ok, _} <- send_confirmation(order) do

      Logger.info("Order created successfully",
        order_id: order.id,
        total: order.total
      )

      {:ok, order}
    else
      {:error, step, reason} ->
        Logger.error("Order creation failed",
          step: step,
          reason: inspect(reason)
        )
        {:error, reason}
    end
  end

  defp build_order(user_id, items) do
    Logger.debug("Building order")
    # ...
  end

  defp validate_order(order) do
    Logger.debug("Validating order", order_id: order.id)
    # ...
  end

  defp persist_order(order) do
    Logger.debug("Persisting order", order_id: order.id)
    # ...
  end

  defp send_confirmation(order) do
    Logger.debug("Sending confirmation", order_id: order.id)
    # ...
  end
end
```

### Background Job Logging

```elixir
defmodule MyApp.EmailWorker do
  require Logger

  def perform(job) do
    Logger.metadata(
      job_id: job.id,
      job_type: "email",
      attempt: job.attempt
    )

    Logger.info("Starting email job",
      to: job.args["to"],
      template: job.args["template"]
    )

    start_time = System.monotonic_time(:millisecond)

    result = try do
      send_email(job.args)
    rescue
      error ->
        Logger.error("Email job failed",
          error: Exception.message(error),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )
        {:error, error}
    end

    duration = System.monotonic_time(:millisecond) - start_time

    case result do
      :ok ->
        Logger.info("Email job completed", duration_ms: duration)
      {:error, _} ->
        Logger.warning("Email job will retry", duration_ms: duration)
    end

    result
  end
end
```

### External API Client Logging

```elixir
defmodule MyApp.StripeClient do
  require Logger

  def create_charge(amount, currency, source) do
    request_id = generate_request_id()
    Logger.metadata(stripe_request_id: request_id)

    Logger.info("Creating Stripe charge",
      amount: amount,
      currency: currency
    )

    start_time = System.monotonic_time(:millisecond)

    result = make_request("/v1/charges", %{
      amount: amount,
      currency: currency,
      source: source
    })

    duration = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{"id" => charge_id}} ->
        Logger.info("Stripe charge created",
          charge_id: charge_id,
          duration_ms: duration
        )
        {:ok, charge_id}

      {:error, %{"error" => error}} ->
        Logger.error("Stripe charge failed",
          error_type: error["type"],
          error_code: error["code"],
          error_message: error["message"],
          duration_ms: duration
        )
        {:error, error}
    end
  end

  defp make_request(path, params) do
    # HTTP request implementation
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
```

### Distributed System Logging

```elixir
defmodule MyApp.DistributedLogger do
  require Logger

  def with_trace(fun) do
    trace_id = generate_trace_id()
    span_id = generate_span_id()

    Logger.metadata(
      trace_id: trace_id,
      span_id: span_id,
      node: node()
    )

    fun.()
  end

  def with_child_span(parent_span_id, fun) do
    span_id = generate_span_id()

    Logger.metadata(
      parent_span_id: parent_span_id,
      span_id: span_id
    )

    fun.()
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end

# Usage
MyApp.DistributedLogger.with_trace(fn ->
  Logger.info("Starting distributed operation")

  MyApp.DistributedLogger.with_child_span(Logger.metadata()[:span_id], fn ->
    Logger.info("Processing in child span")
  end)

  Logger.info("Distributed operation complete")
end)
```

### Error Context Logging

```elixir
defmodule MyApp.ErrorLogger do
  require Logger

  def log_exception(exception, stacktrace, context \\ %{}) do
    Logger.error("Unhandled exception",
      Map.merge(context, %{
        exception_type: exception.__struct__,
        exception_message: Exception.message(exception),
        stacktrace: format_stacktrace(stacktrace)
      })
    )
  end

  def with_error_context(context, fun) do
    try do
      fun.()
    rescue
      e ->
        log_exception(e, __STACKTRACE__, context)
        reraise e, __STACKTRACE__
    end
  end

  defp format_stacktrace(stacktrace) do
    stacktrace
    |> Exception.format_stacktrace()
    |> String.split("\n")
    |> Enum.take(5)
    |> Enum.join(" | ")
  end
end

# Usage
MyApp.ErrorLogger.with_error_context(%{operation: "process_payment", order_id: 123}, fn ->
  process_payment()
end)
```

## Log Analysis

### Parsing Logfmt Output

```bash
# grep for specific requests
grep 'request_id=abc123' /var/log/app.log

# Find slow requests
grep 'duration_ms=' /var/log/app.log | awk -F'duration_ms=' '{print $2}' | sort -n

# Count errors by type
grep 'level=error' /var/log/app.log | grep -oP 'error_type=\K\w+' | sort | uniq -c

# Filter by user
grep 'user_id=42' /var/log/app.log
```

### Using with Log Aggregation

```elixir
# Logs work great with:
# - Grafana Loki (native logfmt support)
# - Elasticsearch (with logfmt parser)
# - Datadog (auto-parsed)
# - Splunk (with field extraction)

# Example: structured query in Loki
# {app="my_app"} | logfmt | level="error" | duration_ms > 1000
```

### Custom Log Processor

```elixir
defmodule LogParser do
  @doc """
  Parse a logfmt line into a map.
  """
  def parse(line) do
    line
    |> String.split(" ")
    |> Enum.map(&parse_pair/1)
    |> Enum.into(%{})
  end

  defp parse_pair(pair) do
    case String.split(pair, "=", parts: 2) do
      [key, value] -> {key, unquote_value(value)}
      _ -> {pair, nil}
    end
  end

  defp unquote_value(value) do
    if String.starts_with?(value, "\"") and String.ends_with?(value, "\"") do
      value |> String.slice(1..-2//1) |> String.replace("\\\"", "\"")
    else
      value
    end
  end
end

# Usage
log_line = ~s(timestamp="2024-01-15 10:30:45.123" level=info message="User logged in" user_id=42)
parsed = LogParser.parse(log_line)
# %{"timestamp" => "2024-01-15 10:30:45.123", "level" => "info", "message" => "User logged in", "user_id" => "42"}
```

---

These examples demonstrate comprehensive LoggerLogfmt usage for structured logging in Elixir applications. For more information, see the [README](README.md) and [USAGE_GUIDE](USAGE_GUIDE.md).
