defmodule LoggerLogfmtTest do
  use ExUnit.Case, async: true

  doctest LoggerLogfmt

  test "module documentation exists" do
    assert LoggerLogfmt.__info__(:module) == LoggerLogfmt
  end
end
