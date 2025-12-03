defmodule Logger.Backends.Logfmt do
  @moduledoc """
  A Logfmt formatter for Elixir's Logger.

  This module provides functions to format log messages in the logfmt format,
  a structured logging format that is easy to parse and human-readable.

  ## Features

  - Flexible format configuration with customizable fields
  - Support for metadata filtering (whitelist/blacklist modes)
  - Multiple timestamp formats (Elixir, ISO8601, Unix epoch)
  - Automatic quoting and escaping of values
  - Nested map support with dot notation

  ## Configuration

  Configure the formatter in your `config/config.exs`:

      config :logger, :logfmt,
        format: [:timestamp, :level, :message, :metadata],
        metadata: [:application, :request_id],
        mode: :whitelist,
        timestamp_format: :iso8601

  ## Format Options

  The `:format` option accepts a list of atoms that determine which fields
  to include in the output:

  - `:timestamp` - Log event timestamp
  - `:level` - Log level (debug, info, warn, error)
  - `:message` - Log message
  - `:domain` - Logger domain
  - `:node` - Node name
  - `:pid` - Process identifier
  - `:metadata` - Additional metadata
  - `:file` - Source file
  - `:line` - Line number

  ## Examples

      iex> result = Logger.Backends.Logfmt.format(:info, "User logged in", {{2024, 1, 15}, {10, 30, 45, 123}}, [user_id: 42])
      iex> output = IO.iodata_to_binary(result)
      iex> output =~ ~r/timestamp=2024-01-15T10:30:45.123/
      true
      iex> output =~ ~r/level=info/
      true
      iex> output =~ ~r/message="User logged in"/
      true

  """

  alias Logger.Backends.Logfmt.Encoder

  @default_format [:timestamp, :level, :message, :domain, :node, :pid, :metadata, :file, :line]

  @default_timestamp_key "timestamp"
  @default_level_key "level"
  @default_message_key "message"
  @default_domain_key "domain"
  @default_node_key "node"
  @default_pid_key "pid"
  @default_file_key "file"
  @default_line_key "line"

  @default_whitelist [:application]
  @default_blacklist [:gl, :mfa, :__sentry__, :logger_pubsub_backend, :ansi_color]
  @default_mode :whitelist

  @doc """
  Formats a log message in logfmt format.

  ## Parameters

  - `level` - The log level (`:debug`, `:info`, `:warn`, `:error`)
  - `message` - The log message
  - `timestamp` - The timestamp tuple `{{year, month, day}, {hour, minute, second, millisecond}}`
  - `metadata` - A keyword list of metadata
  - `opts` - Optional keyword list of formatting options

  ## Returns

  An iolist containing the formatted log message.

  ## Examples

      iex> result = Logger.Backends.Logfmt.format(:info, "Hello", {{2024, 1, 1}, {12, 0, 0, 0}}, [])
      iex> output = IO.iodata_to_binary(result)
      iex> output =~ ~r/level=info/
      true
      iex> output =~ ~r/message=Hello/
      true

  """
  def format(level, message, timestamp, metadata, opts \\ []) do
    opts =
      :logger
      |> Application.get_env(:logfmt, [])
      |> Keyword.merge(opts)

    opts
    |> Keyword.get(:format, @default_format)
    |> Enum.map(&encode(&1, level, message, timestamp, metadata, opts))
    |> List.flatten()
    |> Enum.reject(&(&1 == [] || &1 == "" || &1 == nil))
    |> Enum.intersperse(" ")
    |> add_newline()
  end

  defp encode(:timestamp, _level, _message, timestamp, _metadata, opts) do
    key = Keyword.get(opts, :timestamp_key, @default_timestamp_key)
    Encoder.encode(key, timestamp, opts)
  end

  defp encode(:level, level, _message, _timestamp, _metadata, opts) do
    key = Keyword.get(opts, :level_key, @default_level_key)
    Encoder.encode(key, to_string(level), opts)
  end

  defp encode(:message, _level, message, _timestamp, _metadata, opts) do
    key = Keyword.get(opts, :message_key, @default_message_key)
    Encoder.encode(key, message |> to_string() |> String.trim(), opts)
  end

  defp encode(:node, _level, _message, _timestamp, _metadata, opts) do
    key = Keyword.get(opts, :node_key, @default_node_key)
    Encoder.encode(key, to_string(node()), opts)
  end

  defp encode(:domain, _level, _message, _timestamp, metadata, opts) do
    key = Keyword.get(opts, :domain_key, @default_domain_key)
    val = Keyword.get(metadata, :domain, [])

    Encoder.encode(key, val, opts)
  end

  defp encode(:pid, _level, _message, _timestamp, metadata, opts) do
    key = Keyword.get(opts, :pid_key, @default_pid_key)
    val = Keyword.get(metadata, :pid, self())

    Encoder.encode(key, val, opts)
  end

  defp encode(:metadata, _level, _message, _timestamp, metadata, opts) do
    keys = Keyword.get(opts, :metadata, :default)
    mode = Keyword.get(opts, :mode, @default_mode)
    metadata = Keyword.drop(metadata, [:time, :domain, :pid, :file, :line])

    keys = resolve_metadata_keys(keys, mode)
    metadata = filter_metadata(metadata, keys, mode)

    Enum.map(metadata, fn {key, val} ->
      Encoder.encode(key, val, opts)
    end)
  end

  defp encode(:file, _level, _message, _timestamp, metadata, opts) do
    key = Keyword.get(opts, :file_key, @default_file_key)
    val = Keyword.get(metadata, :file, "")

    Encoder.encode(key, to_string(val), opts)
  end

  defp encode(:line, _level, _message, _timestamp, metadata, opts) do
    key = Keyword.get(opts, :line_key, @default_line_key)
    val = Keyword.get(metadata, :line, 0)

    Encoder.encode(key, val, opts)
  end

  defp resolve_metadata_keys(:default, :whitelist), do: @default_whitelist
  defp resolve_metadata_keys(:default, :blacklist), do: @default_blacklist
  defp resolve_metadata_keys(keys, _mode) when is_list(keys), do: keys
  defp resolve_metadata_keys(keys, _mode), do: raise("Invalid metadata format: #{inspect(keys)}")

  defp filter_metadata(metadata, keys, :whitelist) do
    Enum.reduce(keys, [], fn key, acc ->
      if Keyword.has_key?(metadata, key) do
        Keyword.put(acc, key, Keyword.get(metadata, key))
      else
        acc
      end
    end)
  end

  defp filter_metadata(metadata, keys, :blacklist) do
    Enum.reduce(keys, metadata, fn key, acc ->
      Keyword.delete(acc, key)
    end)
  end

  defp filter_metadata(_metadata, _keys, mode) do
    raise "Unknown mode #{mode}"
  end

  defp add_newline(log) do
    [log | "\n"]
  end
end
