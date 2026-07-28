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

  @typedoc "The timestamp tuple Elixir's `:logger` passes to a formatter's `format/4` callback."
  @type timestamp :: {{non_neg_integer(), 1..12, 1..31}, {0..23, 0..59, 0..59, 0..999}}

  @typedoc "One of the atoms accepted in the `:format` option, selecting a field to render."
  @type format_field :: :timestamp | :level | :message | :domain | :node | :pid | :metadata | :file | :line

  @typedoc "Metadata filtering mode: `:whitelist` includes only the listed keys, `:blacklist` excludes them."
  @type mode :: :whitelist | :blacklist

  @doc """
  Formats a log message in logfmt format.

  This is the function configured as `{Logger.Backends.Logfmt, :format}` in
  `config :logger, :console, format: ...` - Elixir's `:logger` application calls it
  once per log event with that event's level, message, timestamp, and metadata.

  ## Parameters

  - `level` - The log level (`:debug`, `:info`, `:warning`, `:error`, etc. - see `t:Logger.level/0`)
  - `message` - The log message
  - `timestamp` - The timestamp tuple `{{year, month, day}, {hour, minute, second, millisecond}}`
  - `metadata` - A keyword list of metadata
  - `opts` - Optional keyword list of formatting options (merged over `config :logger, :logfmt`);
    see `t:format_field/0` and `t:mode/0` for the atoms accepted below

    - `:format` - list of `t:format_field/0` fields to include, in order (default: all fields)
    - `:metadata` - `:default` or an explicit list of metadata keys to whitelist/blacklist
    - `:mode` - `t:mode/0`, `:whitelist` (default) or `:blacklist`
    - `:delimiter` - key-value delimiter character (default: `?=`)
    - `:timestamp_format` - `:elixir`, `:iso8601` (default), or `:epoch_time`
    - `:metadata_timestamp_format` - same formats, applied to `DateTime`/`NaiveDateTime`
      metadata values (default: `:epoch_time`)
    - `:timestamp_key`, `:level_key`, `:message_key`, `:domain_key`, `:node_key`, `:pid_key`,
      `:file_key`, `:line_key` - rename the corresponding output key

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
  @spec format(Logger.level(), Logger.message(), timestamp(), keyword(), keyword()) :: iodata()
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

  # Renders a single `:format` field to its logfmt key-value string (or, for
  # `:metadata`, a list of them). Dispatches on the field atom; unmatched atoms
  # aren't handled here and would raise `FunctionClauseError` from `format/5`.
  @spec encode(format_field(), Logger.level(), Logger.message(), timestamp(), keyword(), keyword()) ::
          iodata()
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

  # Resolves the `:metadata` option to a concrete list of keys: `:default` picks the
  # built-in whitelist or blacklist depending on `mode`, an explicit list passes
  # through unchanged, and anything else is a configuration error.
  @spec resolve_metadata_keys(:default | [atom()], atom()) :: [atom()]
  defp resolve_metadata_keys(:default, :whitelist), do: @default_whitelist
  defp resolve_metadata_keys(:default, :blacklist), do: @default_blacklist
  defp resolve_metadata_keys(keys, _mode) when is_list(keys), do: keys
  defp resolve_metadata_keys(keys, _mode), do: raise("Invalid metadata format: #{inspect(keys)}")

  # Applies the resolved `keys` to the metadata keyword list according to `mode`:
  # `:whitelist` keeps only entries whose key is in `keys` (preserving `keys`' order),
  # `:blacklist` keeps everything except entries whose key is in `keys`.
  @spec filter_metadata(keyword(), [atom()], atom()) :: keyword()
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

  @spec add_newline(iodata()) :: iodata()
  defp add_newline(log) do
    [log, "\n"]
  end
end
