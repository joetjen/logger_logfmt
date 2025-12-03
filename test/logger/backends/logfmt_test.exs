defmodule Logger.Backends.LogfmtTest do
  use ExUnit.Case, async: true

  alias Logger.Backends.Logfmt

  doctest Logfmt

  describe "format/5" do
    test "formats a basic log message" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 123}}
      result = Logfmt.format(:info, "Hello World", timestamp, [])

      assert IO.iodata_to_binary(result) =~ ~r/timestamp=2024-01-15T10:30:45.123/
      assert IO.iodata_to_binary(result) =~ ~r/level=info/
      assert IO.iodata_to_binary(result) =~ ~r/message="Hello World"/
    end

    test "formats log with metadata" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 123}}
      metadata = [application: :my_app, user_id: 42]

      result =
        Logfmt.format(:info, "User action", timestamp, metadata, metadata: [:application, :user_id], mode: :whitelist)

      output = IO.iodata_to_binary(result)

      assert output =~ ~r/application=:my_app/
      assert output =~ ~r/user_id=42/
    end

    test "formats different log levels" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}

      for level <- [:debug, :info, :warn, :error] do
        result = Logfmt.format(level, "Test", timestamp, [])
        output = IO.iodata_to_binary(result)
        assert output =~ ~r/level=#{level}/
      end
    end

    test "includes node information" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test", timestamp, [])
      output = IO.iodata_to_binary(result)

      assert output =~ ~r/node=/
    end

    test "includes pid from metadata" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test", timestamp, pid: self())
      output = IO.iodata_to_binary(result)

      assert output =~ ~r/pid=/
    end

    test "includes domain from metadata" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test", timestamp, domain: [:my_domain])
      output = IO.iodata_to_binary(result)

      assert output =~ ~r/domain=/
    end

    test "includes file and line from metadata" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test", timestamp, file: "test.ex", line: 42)
      output = IO.iodata_to_binary(result)

      assert output =~ ~r/file=test\.ex/
      assert output =~ ~r/line=42/
    end

    test "respects custom format" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test", timestamp, [], format: [:level, :message])
      output = IO.iodata_to_binary(result)

      assert output =~ ~r/level=info/
      assert output =~ ~r/message=Test/
      refute output =~ ~r/timestamp=/
    end

    test "filters metadata with whitelist mode" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      metadata = [application: :my_app, secret: "password", user_id: 123]

      result =
        Logfmt.format(:info, "Test", timestamp, metadata,
          metadata: [:application, :user_id],
          mode: :whitelist
        )

      output = IO.iodata_to_binary(result)

      assert output =~ ~r/application=:my_app/
      assert output =~ ~r/user_id=123/
      refute output =~ ~r/secret/
    end

    test "filters metadata with blacklist mode" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      metadata = [application: :my_app, gl: "group_leader", user_id: 123]

      result =
        Logfmt.format(:info, "Test", timestamp, metadata,
          metadata: [:gl],
          mode: :blacklist
        )

      output = IO.iodata_to_binary(result)

      assert output =~ ~r/application=:my_app/
      assert output =~ ~r/user_id=123/
      refute output =~ ~r/gl=/
    end

    test "uses default whitelist when metadata is :default" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      metadata = [application: :my_app, gl: "group_leader", mfa: {Mod, :fun, 1}]

      result =
        Logfmt.format(:info, "Test", timestamp, metadata,
          metadata: :default,
          mode: :whitelist
        )

      output = IO.iodata_to_binary(result)

      assert output =~ ~r/application=:my_app/
      refute output =~ ~r/gl=/
      refute output =~ ~r/mfa=/
    end

    test "uses default blacklist when metadata is :default" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      metadata = [application: :my_app, gl: "group_leader", user_id: 123]

      result =
        Logfmt.format(:info, "Test", timestamp, metadata,
          metadata: :default,
          mode: :blacklist
        )

      output = IO.iodata_to_binary(result)

      assert output =~ ~r/application=:my_app/
      assert output =~ ~r/user_id=123/
      refute output =~ ~r/gl=/
    end

    test "custom timestamp key" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test", timestamp, [], timestamp_key: "ts")
      output = IO.iodata_to_binary(result)

      assert output =~ ~r/ts=/
      refute output =~ ~r/timestamp=/
    end

    test "custom level key" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test", timestamp, [], level_key: "severity")
      output = IO.iodata_to_binary(result)

      assert output =~ ~r/severity=info/
      refute output =~ ~r/level=/
    end

    test "custom message key" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test", timestamp, [], message_key: "msg")
      output = IO.iodata_to_binary(result)

      assert output =~ ~r/msg=Test/
      refute output =~ ~r/message=/
    end

    test "ends with newline" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test", timestamp, [])
      output = IO.iodata_to_binary(result)

      assert String.ends_with?(output, "\n")
    end

    test "handles empty metadata list" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test", timestamp, [])
      output = IO.iodata_to_binary(result)

      assert output =~ ~r/level=info/
      assert output =~ ~r/message=Test/
    end

    test "handles messages with special characters" do
      timestamp = {{2024, 1, 15}, {10, 30, 45, 0}}
      result = Logfmt.format(:info, "Test with \"quotes\" and spaces", timestamp, [])
      output = IO.iodata_to_binary(result)

      assert output =~ ~r/message=/
    end
  end
end
