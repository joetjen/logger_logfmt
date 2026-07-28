defmodule Logger.Backends.Logfmt.Encoder do
  @moduledoc """
  Encodes key-value pairs in logfmt format.

  This module handles the encoding of various Elixir data types into
  logfmt-compliant key-value pairs, with proper quoting and escaping.

  ## Supported Types

  - Integers and floats
  - Booleans
  - Atoms
  - Strings (with automatic quoting when needed)
  - Timestamps (multiple formats supported)
  - DateTime and NaiveDateTime structs
  - Structs implementing the `String.Chars` protocol (encoded via `to_string/1`)
  - Maps and other structs (encoded with dot notation for nested keys)
  - Any other type implementing `String.Chars` (encoded via `to_string/1`)
  - Any other type (fallback to `inspect/2`)

  ## Timestamp Formats

  - `:elixir` - "2024-01-15 10:30:45.123"
  - `:iso8601` - "2024-01-15T10:30:45.123Z"
  - `:epoch_time` - Unix timestamp (seconds since epoch)

  ## Time Unit Detection for epoch_time

  When using `:epoch_time` format with DateTime or NaiveDateTime values,
  the time unit is automatically detected from the key suffix:

  - `*_ms` - milliseconds (e.g., `timestamp_ms=1732579200000`)
  - `*_us` - microseconds (e.g., `created_at_us=1732579200000000`)
  - `*_ns` - nanoseconds (e.g., `event_time_ns=1732579200000000000`)
  - No suffix - seconds (e.g., `timestamp=1732579200`)

  ## Examples

      iex> Logger.Backends.Logfmt.Encoder.encode("level", "info")
      "level=info"

      iex> Logger.Backends.Logfmt.Encoder.encode("count", 42)
      "count=42"

      iex> Logger.Backends.Logfmt.Encoder.encode("message", "Hello World")
      "message=\\"Hello World\\""

  """

  alias Logger.Backends.Logfmt.Quoter

  @delimiter ?=
  @unix_epoch 62_167_219_200
  @default_timestamp_format :iso8601
  @default_metadata_timestamp_format :epoch_time

  @typedoc "A Logger timestamp tuple, as passed to a `:logger` formatter's `format/4` callback."
  @type logger_timestamp :: {{non_neg_integer(), 1..12, 1..31}, {0..23, 0..59, 0..59, 0..999}}

  @typedoc "A `DateTime.to_unix/2`-compatible time unit."
  @type time_unit :: :second | :millisecond | :microsecond | :nanosecond

  @doc """
  Encodes a key-value pair in logfmt format.

  ## Parameters

  - `key` - The key (will be converted to string)
  - `val` - The value to encode
  - `opts` - Optional keyword list with encoding options:
    - `:delimiter` - Key-value delimiter (default: `=`)
    - `:timestamp_format` - Format for timestamp values (default: `:elixir`)
    - `:prefix` - Prefix for nested keys (default: `""`)

  ## Returns

  A string or iolist representing the encoded key-value pair.

  ## Examples

      iex> Logger.Backends.Logfmt.Encoder.encode("name", "John")
      "name=John"

      iex> Logger.Backends.Logfmt.Encoder.encode("count", 42)
      "count=42"

  """
  @spec encode(term(), term(), keyword()) :: String.t() | iolist()
  def encode(key, val, opts \\ [])

  def encode(nil, val, opts) do
    encode("nil", val, opts)
  end

  def encode(key, val, opts) when not is_binary(key) do
    key |> to_string() |> encode(val, opts)
  end

  def encode(key, {{yy, mm, dd}, {hh, mi, ss, ms}} = timestamp, opts)
      when yy >= 1970 and mm in 1..12 and dd in 1..31 and hh in 0..23 and mi in 0..59 and
             ss in 0..59 and ms in 0..999 do
    timestamp_format = Keyword.get(opts, :timestamp_format, @default_timestamp_format)

    timestamp_str =
      timestamp_format
      |> to_timestamp(timestamp)
      |> to_string()
      |> Quoter.maybe_quote()

    build(key, opts, timestamp_str)
  end

  def encode(key, %DateTime{} = datetime, opts) do
    timestamp_format = Keyword.get(opts, :metadata_timestamp_format, @default_metadata_timestamp_format)
    time_unit = detect_time_unit(key, timestamp_format)

    timestamp_str =
      timestamp_format
      |> datetime_to_timestamp(datetime, time_unit)
      |> to_string()
      |> Quoter.maybe_quote()

    build(key, opts, timestamp_str)
  end

  def encode(key, %NaiveDateTime{} = datetime, opts) do
    timestamp_format = Keyword.get(opts, :metadata_timestamp_format, @default_metadata_timestamp_format)
    time_unit = detect_time_unit(key, timestamp_format)

    timestamp_str =
      timestamp_format
      |> naive_datetime_to_timestamp(datetime, time_unit)
      |> to_string()
      |> Quoter.maybe_quote()

    build(key, opts, timestamp_str)
  end

  def encode(key, val, opts) when is_integer(val) do
    build(key, opts, Integer.to_string(val, 10))
  end

  def encode(key, val, opts) when is_float(val) do
    build(key, opts, Float.to_string(val))
  end

  def encode(key, true, opts), do: build(key, opts, "true")
  def encode(key, false, opts), do: build(key, opts, "false")
  def encode(key, nil, opts), do: build(key, opts, "nil")

  def encode(key, val, opts) when is_atom(val) do
    build(key, opts, val |> inspect(width: :infinity) |> Quoter.maybe_quote())
  end

  def encode(key, val, opts) when is_binary(val) do
    build(key, opts, Quoter.maybe_quote(val))
  end

  def encode(key, %{__struct__: _} = val, opts) do
    case safe_to_string(val) do
      {:ok, str} -> build(key, opts, Quoter.maybe_quote(str))
      :error -> encode_map(key, val, opts)
    end
  end

  def encode(key, val, opts) when is_map(val) do
    encode_map(key, val, opts)
  end

  def encode(key, val, opts) do
    str =
      case safe_to_string(val) do
        {:ok, str} -> str
        :error -> inspect(val, width: :infinity)
      end

    build(key, opts, Quoter.maybe_quote(str))
  end

  # Assembles the final `prefix key delimiter value` iodata shared by every encode
  # clause, so each clause only has to produce the already-quoted value string.
  @spec build(term(), keyword(), iodata()) :: String.t()
  defp build(key, opts, str) do
    delimiter = Keyword.get(opts, :delimiter, @delimiter)
    to_string([opts[:prefix] || "", key, delimiter, str])
  end

  # `String.Chars.impl_for/1` reports whether a type has an implementation, but
  # that implementation can still raise for a given value (e.g. lists that
  # aren't valid chardata), so guard the call and fall back on failure.
  @spec safe_to_string(term()) :: {:ok, String.t()} | :error
  defp safe_to_string(val) do
    if String.Chars.impl_for(val) do
      {:ok, to_string(val)}
    else
      :error
    end
  rescue
    _ -> :error
  end

  # Encodes a map (or struct, with `__struct__` dropped) as a flat list of
  # dot-notation `key.subkey=value` pairs, recursing into nested maps.
  @spec encode_map(term(), map(), keyword()) :: String.t()
  defp encode_map(key, val, opts) do
    val
    |> Map.keys()
    |> List.delete(:__struct__)
    |> Enum.map(fn k ->
      k |> to_string() |> encode(Map.get(val, k), [{:prefix, (opts[:prefix] || "") <> key <> "."}])
    end)
    |> Enum.intersperse(" ")
    |> to_string()
    |> String.trim_leading()
  end

  # Renders a raw Logger timestamp tuple in the requested `:timestamp_format`.
  @spec to_timestamp(:elixir | :iso8601 | :epoch_time, logger_timestamp()) :: iodata() | integer()
  defp to_timestamp(:elixir, {date, time}) do
    [to_elixir_date(date), " ", to_elixir_time(time)]
  end

  defp to_timestamp(:iso8601, date_and_time) do
    date_and_time
    |> to_naive_date_time()
    |> NaiveDateTime.to_iso8601()
  end

  defp to_timestamp(:epoch_time, date_and_time) do
    {ss, _ms} =
      date_and_time
      |> to_naive_date_time()
      |> NaiveDateTime.to_gregorian_seconds()

    ss - @unix_epoch
  end

  # Renders a `DateTime` metadata value in the requested `:metadata_timestamp_format`.
  @spec datetime_to_timestamp(:elixir | :iso8601 | :epoch_time, DateTime.t(), time_unit()) ::
          String.t() | integer()
  defp datetime_to_timestamp(:elixir, %DateTime{} = datetime, _time_unit) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end

  defp datetime_to_timestamp(:iso8601, %DateTime{} = datetime, _time_unit) do
    DateTime.to_iso8601(datetime)
  end

  defp datetime_to_timestamp(:epoch_time, %DateTime{} = datetime, time_unit) do
    DateTime.to_unix(datetime, time_unit)
  end

  # Renders a `NaiveDateTime` metadata value in the requested `:metadata_timestamp_format`.
  @spec naive_datetime_to_timestamp(:elixir | :iso8601 | :epoch_time, NaiveDateTime.t(), time_unit()) ::
          String.t() | integer()
  defp naive_datetime_to_timestamp(:elixir, %NaiveDateTime{} = datetime, _time_unit) do
    NaiveDateTime.to_string(datetime)
  end

  defp naive_datetime_to_timestamp(:iso8601, %NaiveDateTime{} = datetime, _time_unit) do
    NaiveDateTime.to_iso8601(datetime)
  end

  defp naive_datetime_to_timestamp(:epoch_time, %NaiveDateTime{} = datetime, time_unit) do
    {ss, us} = NaiveDateTime.to_gregorian_seconds(datetime)
    base_seconds = ss - @unix_epoch

    case time_unit do
      :second -> base_seconds
      :millisecond -> base_seconds * 1_000 + div(us, 1_000)
      :microsecond -> base_seconds * 1_000_000 + us
      :nanosecond -> base_seconds * 1_000_000_000 + us * 1_000
    end
  end

  # Only `:epoch_time` supports per-key time unit detection; other formats always
  # render a single string regardless of key suffix, so they short-circuit to `:second`.
  @spec detect_time_unit(String.t(), atom()) :: time_unit()
  defp detect_time_unit(key, :epoch_time) do
    cond do
      String.ends_with?(key, "_ns") -> :nanosecond
      String.ends_with?(key, "_us") -> :microsecond
      String.ends_with?(key, "_ms") -> :millisecond
      true -> :second
    end
  end

  defp detect_time_unit(_key, _format), do: :second

  @spec to_elixir_date({non_neg_integer(), 1..12, 1..31}) :: iodata()
  defp to_elixir_date({yy, mm, dd}) do
    [Integer.to_string(yy), ?-, pad(mm, 2), ?-, pad(dd, 2)]
  end

  @spec to_elixir_time({0..23, 0..59, 0..59, 0..999}) :: iodata()
  defp to_elixir_time({hh, mi, ss, ms}) do
    [pad(hh, 2), ?:, pad(mi, 2), ?:, pad(ss, 2), ?., pad(ms, 3)]
  end

  @spec to_naive_date_time(logger_timestamp()) :: NaiveDateTime.t()
  defp to_naive_date_time({{yy, mm, dd}, {hh, mi, ss, ms}}) do
    date = Date.new!(yy, mm, dd)
    time = Time.new!(hh, mi, ss, {ms * 1000, 3})

    NaiveDateTime.new!(date, time)
  end

  # Zero-pads an integer to `width` digits (only `2` and `3` are used, for the date/time
  # and millisecond components respectively).
  @spec pad(non_neg_integer(), 2 | 3) :: iodata()
  defp pad(int, 2) when int < 10, do: [?0, Integer.to_string(int)]
  defp pad(int, 2), do: Integer.to_string(int)

  defp pad(int, 3) when int < 10, do: [?0, ?0, Integer.to_string(int)]
  defp pad(int, 3) when int < 100, do: [?0, Integer.to_string(int)]
  defp pad(int, 3), do: Integer.to_string(int)
end
