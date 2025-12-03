defmodule Logger.Backends.Logfmt.Quoter do
  @moduledoc """
  Handles quoting and escaping of values for logfmt format.

  This module determines whether a value needs quoting and/or escaping
  according to the logfmt specification and applies the necessary
  transformations.

  ## Quoting Rules

  A value needs quoting if it contains:
  - Spaces
  - Equal signs (=)
  - Backslashes (\\)
  - Control characters (0x00-0x1F, 0x7F)
  - Double quotes (")

  ## Escaping

  Special characters are escaped using standard escape sequences:
  - `\\t` for tab
  - `\\n` for newline
  - `\\r` for carriage return
  - `\\"` for double quote
  - `\\\\` for backslash
  - `\\uXXXX` for control characters

  ## Examples

      iex> Logger.Backends.Logfmt.Quoter.maybe_quote("simple")
      "simple"

      iex> Logger.Backends.Logfmt.Quoter.maybe_quote("hello world")
      [?", "hello world", ?"]

      iex> Logger.Backends.Logfmt.Quoter.maybe_quote("has\\"quote")
      [?", "has\\\\\\"quote", ?"]

  """

  @quote ?"

  @doc """
  Quotes a value if necessary based on its content.

  ## Parameters

  - `val` - The string value to potentially quote

  ## Returns

  - The original string if no quoting is needed
  - An iolist with quotes if quoting is needed
  - An iolist with quotes and escaped content if escaping is needed

  ## Examples

      iex> Logger.Backends.Logfmt.Quoter.maybe_quote("noSpaces")
      "noSpaces"

      iex> Logger.Backends.Logfmt.Quoter.maybe_quote("has space")
      [34, "has space", 34]

  """
  def maybe_quote(val) do
    case infer_quote(val) do
      :none -> val
      :quoting -> [@quote, val, @quote]
      :quoting_and_escaping -> [@quote, escape(val), @quote]
    end
  end

  @doc """
  Determines the quoting strategy needed for a value.

  ## Parameters

  - `val` - The string value to analyze

  ## Returns

  - `:none` - No quoting needed
  - `:quoting` - Needs quotes but no escaping
  - `:quoting_and_escaping` - Needs both quotes and escaping

  ## Examples

      iex> Logger.Backends.Logfmt.Quoter.infer_quote("simple")
      :none

      iex> Logger.Backends.Logfmt.Quoter.infer_quote("has space")
      :quoting

      iex> Logger.Backends.Logfmt.Quoter.infer_quote("has\\"quote")
      :quoting_and_escaping

  """
  def infer_quote(val), do: infer_quote(val, :none)

  defp infer_quote(<<>>, acc), do: acc
  defp infer_quote(<<" ", rest::binary>>, _acc), do: infer_quote(rest, :quoting)
  defp infer_quote(<<"\"", _rest::binary>>, _acc), do: :quoting_and_escaping
  defp infer_quote(<<"=", rest::binary>>, _acc), do: infer_quote(rest, :quoting)
  defp infer_quote(<<"\\", _rest::binary>>, _acc), do: :quoting_and_escaping
  defp infer_quote(<<c, _rest::binary>>, _acc) when c <= 0x1F, do: :quoting_and_escaping
  defp infer_quote(<<c, _rest::binary>>, _acc) when c == 0x7F, do: :quoting_and_escaping
  defp infer_quote(<<_, rest::binary>>, acc), do: infer_quote(rest, acc)

  @doc """
  Escapes special characters in a string.

  ## Parameters

  - `val` - The string to escape

  ## Returns

  A string with all special characters properly escaped.

  ## Examples

      iex> Logger.Backends.Logfmt.Quoter.escape("hello\\nworld")
      "hello\\\\nworld"

      iex> Logger.Backends.Logfmt.Quoter.escape("has\\"quote")
      "has\\\\\\"quote"

  """
  def escape(val), do: escape(val, "")

  defp escape(<<>>, acc), do: acc
  defp escape(<<0x0, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0000">>)
  defp escape(<<0x1, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0001">>)
  defp escape(<<0x2, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0002">>)
  defp escape(<<0x3, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0003">>)
  defp escape(<<0x4, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0004">>)
  defp escape(<<0x5, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0005">>)
  defp escape(<<0x6, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0006">>)
  defp escape(<<0x7, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0007">>)
  defp escape(<<0x8, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0008">>)
  defp escape(<<"\t", rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\t">>)
  defp escape(<<"\n", rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\n">>)
  defp escape(<<0xB, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u000b">>)
  defp escape(<<0xC, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u000c">>)
  defp escape(<<"\r", rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\r">>)
  defp escape(<<0xE, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u000e">>)
  defp escape(<<0xF, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u000f">>)
  defp escape(<<0x10, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0010">>)
  defp escape(<<0x11, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0011">>)
  defp escape(<<0x12, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0012">>)
  defp escape(<<0x13, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0013">>)
  defp escape(<<0x14, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0014">>)
  defp escape(<<0x15, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0015">>)
  defp escape(<<0x16, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0016">>)
  defp escape(<<0x17, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0017">>)
  defp escape(<<0x18, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0018">>)
  defp escape(<<0x19, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u0019">>)
  defp escape(<<0x1A, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u001a">>)
  defp escape(<<0x1B, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u001b">>)
  defp escape(<<0x1C, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u001c">>)
  defp escape(<<0x1D, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u001d">>)
  defp escape(<<0x1E, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u001e">>)
  defp escape(<<0x1F, rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\u001f">>)
  defp escape(<<"\"", rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\\"">>)
  defp escape(<<"\\", rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\\\">>)
  defp escape(<<c, rest::binary>>, acc), do: escape(rest, <<acc::binary, c>>)
end
