defmodule LoggerLogfmt do
  @moduledoc """
  A logfmt formatter for Elixir's Logger.

  LoggerLogfmt provides a structured logging format that outputs key-value pairs
  in the logfmt format, which is both human-readable and machine-parseable.

  ## Overview

  The logfmt format is a simple, text-based format for structured logs, where each
  log line consists of key-value pairs separated by spaces. Values that contain
  spaces or special characters are automatically quoted.

  ## Features

  - **Flexible Configuration**: Customize which fields appear in logs
  - **Metadata Filtering**: Whitelist or blacklist metadata fields
  - **Multiple Timestamp Formats**: Support for Elixir, ISO8601, and Unix epoch formats
  - **Automatic Quoting**: Values with special characters are properly quoted and escaped
  - **Nested Maps**: Supports nested structures with dot notation
  - **Zero Dependencies**: Pure Elixir implementation

  ## Installation

  Add `logger_logfmt` to your list of dependencies in `mix.exs`:

      def deps do
        [
          {:logger_logfmt, "~> 0.1.0"}
        ]
      end

  ## Configuration

  Configure the formatter in your `config/config.exs`:

      config :logger, :console,
        format: {Logger.Backends.Logfmt, :format},
        metadata: [:request_id, :user_id]

      config :logger, :logfmt,
        format: [:timestamp, :level, :message, :metadata],
        metadata: [:application, :request_id],
        mode: :whitelist,
        timestamp_format: :iso8601

  ## Format Options

  The `:format` option accepts a list of atoms:

  - `:timestamp` - Log event timestamp
  - `:level` - Log level (debug, info, warn, error)
  - `:message` - Log message
  - `:domain` - Logger domain
  - `:node` - Node name
  - `:pid` - Process identifier
  - `:metadata` - Additional metadata
  - `:file` - Source file
  - `:line` - Line number

  ## Usage Example

      require Logger

      # Simple log
      Logger.info("User logged in")
      # Output: timestamp="2024-01-15 10:30:45.123" level=info message="User logged in"

      # With metadata
      Logger.info("Payment processed", amount: 99.99, currency: "USD")
      # Output: timestamp="2024-01-15 10:30:45.123" level=info message="Payment processed" amount=99.99 currency=USD

  ## Metadata Filtering

  ### Whitelist Mode (default)

      config :logger, :logfmt,
        metadata: [:request_id, :user_id],
        mode: :whitelist

  Only the specified keys will be included in the log output.

  ### Blacklist Mode

      config :logger, :logfmt,
        metadata: [:password, :credit_card],
        mode: :blacklist

  All metadata except the specified keys will be included.

  ## Timestamp Formats

  - `:elixir` - "2024-01-15 10:30:45.123" (default)
  - `:iso8601` - "2024-01-15T10:30:45.123"
  - `:epoch_time` - Unix timestamp in seconds

  ## Main Modules

  - `Logger.Backends.Logfmt` - Main formatter module
  - `Logger.Backends.Logfmt.Encoder` - Encodes key-value pairs
  - `Logger.Backends.Logfmt.Quoter` - Handles quoting and escaping
  """
end
