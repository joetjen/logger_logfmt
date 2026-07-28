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

  @typedoc "The quoting strategy required for a value, as determined by `infer_quote/1`."
  @type quote_strategy :: :none | :quoting | :quoting_and_escaping

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
  @spec maybe_quote(String.t()) :: String.t() | iolist()
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
  @spec infer_quote(String.t()) :: quote_strategy()
  def infer_quote(val), do: infer_quote(val, :none)

  # Scans the binary byte by byte, tracking the strictest quoting requirement seen so
  # far. A double quote, backslash, or control character short-circuits immediately
  # since nothing can outrank `:quoting_and_escaping`; a space or `=` only upgrades
  # from `:none` and keeps scanning in case a later byte demands escaping too.
  @spec infer_quote(binary(), quote_strategy()) :: quote_strategy()
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
  @spec escape(String.t()) :: String.t()
  def escape(val), do: escape(val, "")

  # Recursively rebuilds the binary, replacing each special character with its escape
  # sequence. Tab/newline/carriage-return/quote/backslash get their short mnemonic
  # escapes; the remaining control characters (0x00-0x1F, 0x7F) get a `\uXXXX` escape.
  @spec escape(binary(), binary()) :: binary()
  defp escape(<<>>, acc), do: acc
  defp escape(<<"\t", rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\t">>)
  defp escape(<<"\n", rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\n">>)
  defp escape(<<"\r", rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\r">>)
  defp escape(<<"\"", rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\\"">>)
  defp escape(<<"\\", rest::binary>>, acc), do: escape(rest, <<acc::binary, "\\\\">>)

  defp escape(<<c, rest::binary>>, acc) when c <= 0x1F or c == 0x7F do
    hex = c |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(4, "0")
    escape(rest, <<acc::binary, "\\u", hex::binary>>)
  end

  defp escape(<<c, rest::binary>>, acc), do: escape(rest, <<acc::binary, c>>)
end
