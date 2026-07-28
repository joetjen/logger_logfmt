defmodule Logger.Backends.Logfmt.QuoterTest do
  use ExUnit.Case, async: true

  alias Logger.Backends.Logfmt.Quoter

  doctest Quoter

  describe "maybe_quote/1" do
    test "does not quote simple strings" do
      assert Quoter.maybe_quote("simple") == "simple"
      assert Quoter.maybe_quote("test123") == "test123"
      assert Quoter.maybe_quote("under_score") == "under_score"
    end

    test "quotes strings with spaces" do
      result = Quoter.maybe_quote("hello world")
      assert IO.iodata_to_binary(result) == ~s("hello world")
    end

    test "quotes strings with equals signs" do
      result = Quoter.maybe_quote("key=value")
      assert IO.iodata_to_binary(result) == ~s("key=value")
    end

    test "quotes and escapes strings with double quotes" do
      result = Quoter.maybe_quote(~s(say "hello"))
      output = IO.iodata_to_binary(result)
      assert String.starts_with?(output, "\"")
      assert String.ends_with?(output, "\"")
      assert output =~ "\\\""
    end

    test "quotes and escapes strings with backslashes" do
      result = Quoter.maybe_quote("path\\to\\file")
      output = IO.iodata_to_binary(result)
      assert String.starts_with?(output, "\"")
      assert String.ends_with?(output, "\"")
      assert output =~ "\\\\"
    end

    test "quotes and escapes strings with newlines" do
      result = Quoter.maybe_quote("line1\nline2")
      output = IO.iodata_to_binary(result)
      assert output == ~s("line1\\nline2")
    end

    test "quotes and escapes strings with tabs" do
      result = Quoter.maybe_quote("col1\tcol2")
      output = IO.iodata_to_binary(result)
      assert output == ~s("col1\\tcol2")
    end

    test "quotes and escapes strings with carriage returns" do
      result = Quoter.maybe_quote("line1\rline2")
      output = IO.iodata_to_binary(result)
      assert output == ~s("line1\\rline2")
    end

    test "quotes and escapes control characters" do
      result = Quoter.maybe_quote("test\x00null")
      output = IO.iodata_to_binary(result)
      assert output == ~s("test\\u0000null")
    end

    test "quotes and escapes delete character" do
      result = Quoter.maybe_quote("test\x7Fdelete")
      output = IO.iodata_to_binary(result)
      assert output == ~s("test\\u007fdelete")
    end

    test "handles empty strings" do
      assert Quoter.maybe_quote("") == ""
    end
  end

  describe "infer_quote/1" do
    test "returns :none for simple strings" do
      assert Quoter.infer_quote("simple") == :none
      assert Quoter.infer_quote("test123") == :none
      assert Quoter.infer_quote("under_score") == :none
    end

    test "returns :quoting for strings with spaces" do
      assert Quoter.infer_quote("hello world") == :quoting
      assert Quoter.infer_quote(" leading") == :quoting
      assert Quoter.infer_quote("trailing ") == :quoting
    end

    test "returns :quoting for strings with equals signs" do
      assert Quoter.infer_quote("key=value") == :quoting
      assert Quoter.infer_quote("=start") == :quoting
      assert Quoter.infer_quote("end=") == :quoting
    end

    test "returns :quoting_and_escaping for strings with double quotes" do
      assert Quoter.infer_quote(~s("quoted")) == :quoting_and_escaping
      assert Quoter.infer_quote(~s(say "hi")) == :quoting_and_escaping
    end

    test "returns :quoting_and_escaping for strings with backslashes" do
      assert Quoter.infer_quote("path\\file") == :quoting_and_escaping
      assert Quoter.infer_quote("\\start") == :quoting_and_escaping
    end

    test "returns :quoting_and_escaping for control characters" do
      assert Quoter.infer_quote("test\x00") == :quoting_and_escaping
      assert Quoter.infer_quote("test\x1F") == :quoting_and_escaping
      assert Quoter.infer_quote("test\x7F") == :quoting_and_escaping
    end

    test "returns :none for empty strings" do
      assert Quoter.infer_quote("") == :none
    end
  end

  describe "escape/1" do
    test "escapes null character" do
      assert Quoter.escape("\x00") == "\\u0000"
    end

    test "escapes tab character" do
      assert Quoter.escape("\t") == "\\t"
    end

    test "escapes newline character" do
      assert Quoter.escape("\n") == "\\n"
    end

    test "escapes carriage return" do
      assert Quoter.escape("\r") == "\\r"
    end

    test "escapes double quote" do
      assert Quoter.escape("\"") == "\\\""
    end

    test "escapes backslash" do
      assert Quoter.escape("\\") == "\\\\"
    end

    test "escapes all control characters" do
      for code <- 0x0..0x1F do
        char = <<code>>
        result = Quoter.escape(char)

        case char do
          "\t" -> assert result == "\\t"
          "\n" -> assert result == "\\n"
          "\r" -> assert result == "\\r"
          _ -> assert result =~ ~r/\\u[0-9a-f]{4}/
        end
      end
    end

    test "escapes the delete character" do
      assert Quoter.escape("\x7F") == "\\u007f"
    end

    test "does not escape normal characters" do
      assert Quoter.escape("abc123") == "abc123"
      assert Quoter.escape("Test String") == "Test String"
    end

    test "handles mixed content" do
      assert Quoter.escape("line1\nline2") == "line1\\nline2"
      assert Quoter.escape("quote\"here") == "quote\\\"here"
      assert Quoter.escape("tab\ttab") == "tab\\ttab"
    end

    test "handles empty strings" do
      assert Quoter.escape("") == ""
    end

    test "preserves unicode characters" do
      assert Quoter.escape("héllo") == "héllo"
      assert Quoter.escape("日本語") == "日本語"
      assert Quoter.escape("emoji 😀") == "emoji 😀"
    end
  end
end
