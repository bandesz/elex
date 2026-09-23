defmodule Elex.CharClassTest do
  use ExUnit.Case, async: true

  alias Elex.CharClass

  test "char lists are the expected NimbleParsec ascii_char specs" do
    assert CharClass.ident_start_chars() == [?a..?z]
    assert CharClass.ident_continue_chars() == [?a..?z, ?0..?9, ?_]
    assert CharClass.unit_start_chars() == [?A..?Z, ?a..?z]
    assert CharClass.unit_continue_chars() == [?A..?Z, ?a..?z, ?0..?9, ?_]
    assert CharClass.digit_chars() == [?0..?9]
    assert CharClass.whitespace_chars() == [?\s, ?\t]
  end

  test "degree sign is a unit-symbol start codepoint and not a byte-class member" do
    assert CharClass.unit_symbol_start?(?°)
    refute CharClass.unit_start?(?°)
    refute CharClass.unit_continue?(?°)
    refute CharClass.unit_symbol_start?(?º)
  end

  test "micro signs start a unit symbol and ohm may start or continue one" do
    assert CharClass.unit_symbol_start?(?µ)
    assert CharClass.unit_symbol_start?(?μ)
    assert CharClass.unit_symbol_start?(?Ω)
    assert CharClass.unit_symbol_start?(?Ω)

    refute CharClass.unit_symbol_continue?(?µ)
    refute CharClass.unit_symbol_continue?(?μ)
    refute CharClass.unit_symbol_continue?(?°)
    assert CharClass.unit_symbol_continue?(?Ω)
    assert CharClass.unit_symbol_continue?(?Ω)
    assert CharClass.unit_symbol_continue?(?k)

    refute CharClass.unit_start?(?µ)
    refute CharClass.unit_continue?(?Ω)
  end

  test "predicates match char list membership for every byte 0..255" do
    classes = [
      {CharClass.ident_start_chars(), &CharClass.ident_start?/1},
      {CharClass.ident_continue_chars(), &CharClass.ident_continue?/1},
      {CharClass.unit_start_chars(), &CharClass.unit_start?/1},
      {CharClass.unit_continue_chars(), &CharClass.unit_continue?/1},
      {CharClass.digit_chars(), &CharClass.digit?/1},
      {CharClass.whitespace_chars(), &CharClass.whitespace?/1}
    ]

    for {chars, pred} <- classes, byte <- 0..255 do
      assert pred.(byte) == member?(chars, byte),
             "byte #{byte} mismatch for #{inspect(chars)}"
    end
  end

  defp member?(specs, byte) do
    Enum.any?(specs, fn
      %Range{} = range -> byte in range
      code when is_integer(code) -> byte == code
    end)
  end
end
