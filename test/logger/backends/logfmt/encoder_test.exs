defmodule Logger.Backends.Logfmt.EncoderTest.Stringable do
  defstruct [:value]
end

defimpl String.Chars, for: Logger.Backends.Logfmt.EncoderTest.Stringable do
  def to_string(%{value: value}), do: "stringable:#{value}"
end

defmodule Logger.Backends.Logfmt.EncoderTest.PlainStruct do
  defstruct name: "test", value: 42
end

defmodule Logger.Backends.Logfmt.EncoderTest do
  use ExUnit.Case, async: true

  alias Logger.Backends.Logfmt.Encoder
  alias Logger.Backends.Logfmt.EncoderTest.PlainStruct
  alias Logger.Backends.Logfmt.EncoderTest.Stringable

  doctest Encoder

  describe "encode/3" do
    test "encodes string values" do
      assert Encoder.encode("key", "value") == "key=value"
      assert Encoder.encode("name", "John Doe") == ~s(name="John Doe")
    end

    test "encodes integer values" do
      assert Encoder.encode("count", 42) == "count=42"
      assert Encoder.encode("negative", -10) == "negative=-10"
      assert Encoder.encode("zero", 0) == "zero=0"
    end

    test "encodes float values" do
      assert Encoder.encode("price", 19.99) == "price=19.99"
      assert Encoder.encode("pi", 3.14159) == "pi=3.14159"
    end

    test "encodes boolean values" do
      assert Encoder.encode("active", true) == "active=true"
      assert Encoder.encode("enabled", false) == "enabled=false"
    end

    test "encodes nil values" do
      assert Encoder.encode("empty", nil) == "empty=nil"
      assert Encoder.encode(nil, "value") == "nil=value"
    end

    test "encodes atom values" do
      assert Encoder.encode("status", :ok) == "status=:ok"
      assert Encoder.encode("level", :info) == "level=:info"
      assert Encoder.encode("atom", :test_atom) == "atom=:test_atom"
    end

    test "converts non-string keys to strings" do
      assert Encoder.encode(:my_key, "value") == "my_key=value"
      assert Encoder.encode(123, "value") == "123=value"
    end

    test "encodes timestamps in elixir format" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 123}}
      result = Encoder.encode("timestamp", timestamp, timestamp_format: :elixir)

      assert result == ~s(timestamp="2024-01-15 10:30:45.123")
    end

    test "encodes timestamps in iso8601 format" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 123}}
      result = Encoder.encode("timestamp", timestamp, timestamp_format: :iso8601)

      assert result == ~s(timestamp=2024-01-15T10:30:45.123)
    end

    test "encodes timestamps in epoch_time format" do
      timestamp = {{1970, 1, 1}, {0, 0, 0, 0}}
      result = Encoder.encode("timestamp", timestamp, timestamp_format: :epoch_time)

      assert result == "timestamp=0"
    end

    test "encodes maps with dot notation" do
      map = %{name: "John", age: 30}
      result = Encoder.encode("user", map)

      assert result =~ "user.name=John"
      assert result =~ "user.age=30"
    end

    test "encodes nested maps" do
      map = %{address: %{city: "Berlin", zip: "10115"}}
      result = Encoder.encode("user", map)

      assert result =~ "user.address.city=Berlin"
      assert result =~ "user.address.zip=10115"
    end

    test "excludes __struct__ from struct encoding" do
      # Use a plain map to simulate struct behavior
      struct_map = %{name: "test", value: 42, __struct__: MyTestStruct}
      result = Encoder.encode("data", struct_map)

      refute result =~ "__struct__"
      assert result =~ "data.name=test"
      assert result =~ "data.value=42"
    end

    test "encodes a struct implementing String.Chars using to_string/1" do
      result = Encoder.encode("thing", %Stringable{value: "abc"})

      assert result == "thing=stringable:abc"
    end

    test "encodes a struct without a String.Chars implementation as a map" do
      result = Encoder.encode("data", %PlainStruct{})

      refute result =~ "__struct__"
      assert result =~ "data.name=test"
      assert result =~ "data.value=42"
    end

    test "uses custom delimiter" do
      result = Encoder.encode("key", "value", delimiter: ?:)
      assert result == "key:value"
    end

    test "uses prefix for nested keys" do
      result = Encoder.encode("name", "John", prefix: "user.")
      assert result == "user.name=John"
    end

    test "handles empty strings" do
      result = Encoder.encode("empty", "")
      assert result == "empty="
    end

    test "handles strings with spaces" do
      result = Encoder.encode("msg", "hello world")
      assert result == ~s(msg="hello world")
    end

    test "handles strings with quotes" do
      result = Encoder.encode("msg", ~s(say "hello"))
      assert result =~ "msg="
      assert result =~ "\\\""
    end

    test "handles strings with equals signs" do
      result = Encoder.encode("formula", "x=y")
      assert result == ~s(formula="x=y")
    end

    test "handles pids" do
      pid = self()
      result = Encoder.encode("pid", pid)
      assert result =~ "pid="
    end

    test "encodes charlists using to_string/1" do
      result = Encoder.encode("items", ~c"abc")
      assert result == "items=abc"
    end

    test "falls back to inspect for lists that are not valid chardata" do
      result = Encoder.encode("items", [1, :a, %{b: 2}])
      assert result =~ "items="
      assert result =~ "1"
      assert result =~ ":a"
    end

    test "handles tuples using inspect" do
      result = Encoder.encode("point", {10, 20})
      assert result =~ "point="
    end

    test "pads single digit months" do
      timestamp = {{2024, 3, 5}, {1, 2, 3, 4}}
      result = Encoder.encode("ts", timestamp, timestamp_format: :elixir)
      assert result == ~s(ts="2024-03-05 01:02:03.004")
    end

    test "handles milliseconds padding" do
      timestamp = {{2024, 1, 1}, {0, 0, 0, 1}}
      result = Encoder.encode("ts", timestamp, timestamp_format: :elixir)
      assert result == ~s(ts="2024-01-01 00:00:00.001")

      timestamp = {{2024, 1, 1}, {0, 0, 0, 99}}
      result = Encoder.encode("ts", timestamp, timestamp_format: :elixir)
      assert result == ~s(ts="2024-01-01 00:00:00.099")
    end

    test "validates timestamp ranges" do
      # Valid timestamp
      timestamp = {{2024, 12, 31}, {23, 59, 59, 999}}
      assert Encoder.encode("ts", timestamp) =~ "ts="

      # Invalid timestamps should fall through to inspect
      invalid = {{2024, 13, 1}, {0, 0, 0, 0}}
      result = Encoder.encode("ts", invalid)
      assert result =~ "ts="
    end

    test "encodes DateTime in epoch_time format (seconds)" do
      datetime = ~U[2024-01-15 10:30:45Z]
      result = Encoder.encode("timestamp", datetime, metadata_timestamp_format: :epoch_time)
      assert result == "timestamp=1705314645"
    end

    test "encodes DateTime in epoch_time format with _ms suffix (milliseconds)" do
      datetime = ~U[2024-01-15 10:30:45.123Z]
      result = Encoder.encode("timestamp_ms", datetime, metadata_timestamp_format: :epoch_time)
      assert result == "timestamp_ms=1705314645123"
    end

    test "encodes DateTime in epoch_time format with _us suffix (microseconds)" do
      datetime = ~U[2024-01-15 10:30:45.123456Z]
      result = Encoder.encode("timestamp_us", datetime, metadata_timestamp_format: :epoch_time)
      assert result == "timestamp_us=1705314645123456"
    end

    test "encodes DateTime in epoch_time format with _ns suffix (nanoseconds)" do
      datetime = ~U[2024-01-15 10:30:45.123456Z]
      result = Encoder.encode("timestamp_ns", datetime, metadata_timestamp_format: :epoch_time)
      assert result == "timestamp_ns=1705314645123456000"
    end

    test "encodes DateTime in iso8601 format" do
      datetime = ~U[2024-01-15 10:30:45.123Z]
      result = Encoder.encode("timestamp", datetime, metadata_timestamp_format: :iso8601)
      assert result == "timestamp=2024-01-15T10:30:45.123Z"
    end

    test "encodes DateTime in elixir format" do
      datetime = ~U[2024-01-15 10:30:45.123Z]
      result = Encoder.encode("timestamp", datetime, metadata_timestamp_format: :elixir)
      assert result == ~s(timestamp="2024-01-15 10:30:45.123")
    end

    test "encodes NaiveDateTime in epoch_time format (seconds)" do
      datetime = ~N[2024-01-15 10:30:45]
      result = Encoder.encode("timestamp", datetime, metadata_timestamp_format: :epoch_time)
      assert result == "timestamp=1705314645"
    end

    test "encodes NaiveDateTime in epoch_time format with _ms suffix (milliseconds)" do
      datetime = ~N[2024-01-15 10:30:45.123]
      result = Encoder.encode("timestamp_ms", datetime, metadata_timestamp_format: :epoch_time)
      assert result == "timestamp_ms=1705314645123"
    end

    test "encodes NaiveDateTime in epoch_time format with _us suffix (microseconds)" do
      datetime = ~N[2024-01-15 10:30:45.123456]
      result = Encoder.encode("timestamp_us", datetime, metadata_timestamp_format: :epoch_time)
      assert result == "timestamp_us=1705314645123456"
    end

    test "encodes NaiveDateTime in epoch_time format with _ns suffix (nanoseconds)" do
      datetime = ~N[2024-01-15 10:30:45.123456]
      result = Encoder.encode("timestamp_ns", datetime, metadata_timestamp_format: :epoch_time)
      assert result == "timestamp_ns=1705314645123456000"
    end

    test "encodes NaiveDateTime in iso8601 format" do
      datetime = ~N[2024-01-15 10:30:45.123]
      result = Encoder.encode("timestamp", datetime, metadata_timestamp_format: :iso8601)
      assert result == "timestamp=2024-01-15T10:30:45.123"
    end

    test "encodes NaiveDateTime in elixir format" do
      datetime = ~N[2024-01-15 10:30:45.123]
      result = Encoder.encode("timestamp", datetime, metadata_timestamp_format: :elixir)
      assert result == ~s(timestamp="2024-01-15 10:30:45.123")
    end

    test "time unit detection only applies to epoch_time format" do
      datetime = ~U[2024-01-15 10:30:45.123Z]
      # Even with _ms suffix, iso8601 format should not change
      result = Encoder.encode("timestamp_ms", datetime, metadata_timestamp_format: :iso8601)
      assert result == "timestamp_ms=2024-01-15T10:30:45.123Z"
    end
  end
end
