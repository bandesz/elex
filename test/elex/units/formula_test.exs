defmodule Elex.Units.FormulaTest do
  use ExUnit.Case, async: true

  alias Elex.Units.Formula

  describe "parse/1" do
    test "parses caret exponent as an integer power" do
      assert Formula.parse("s^2") == {:ok, %{"s" => 2}}
      assert Formula.parse("m | s^2") == Formula.parse("m | s * s")
      assert Formula.parse("m | s^2") == {:ok, %{"m" => 1, "s" => -2}}
    end

    test "treats trailing digits as part of the symbol name" do
      assert Formula.parse("m | s2") == {:ok, %{"m" => 1, "s2" => -1}}
      refute Formula.parse("m | s2") == Formula.parse("m | s^2")
    end

    test "parses a negative integer exponent" do
      assert Formula.parse("s^-2") == {:ok, %{"s" => -2}}
    end

    test "treats whitespace juxtaposition as multiplication" do
      assert Formula.parse("kg m | s^2") == Formula.parse("kg * m | s^2")
      assert Formula.parse("kg m | s^2") == {:ok, %{"kg" => 1, "m" => 1, "s" => -2}}
    end

    test "treats middot as multiplication" do
      assert Formula.parse("kg · m") == Formula.parse("kg * m")
      assert Formula.parse("kg ⋅ m") == Formula.parse("kg * m")
      assert Formula.parse("kg · m") == {:ok, %{"kg" => 1, "m" => 1}}
    end

    test "parses inverse as 1 | s or a negative exponent" do
      assert Formula.parse("1 | s") == {:ok, %{"s" => -1}}
      assert Formula.parse("s^-1") == Formula.parse("1 | s")
    end

    test "allows spaces around ^ and compact |" do
      assert Formula.parse("m | s ^ 2") == Formula.parse("m | s^2")
      assert Formula.parse("km|h") == Formula.parse("km | h")
    end

    test "rejects slash division" do
      assert Formula.parse("m / s") ==
               {:error, "invalid formula 'm / s'; use '|' for division (m | s, km | h), not '/'"}

      assert Formula.parse("km / h") ==
               {:error, "invalid formula 'km / h'; use '|' for division (m | s, km | h), not '/'"}
    end

    test "rejects braces in a formula string" do
      assert Formula.parse("{m | s}") ==
               {:error,
                "invalid formula '{m | s}'; braces belong on a quantity suffix (1 {m | s}), not in unit: or convert"}
    end

    test "rejects a second |" do
      assert {:ok, %{"m" => 1, "s" => -1}} = Formula.parse("m | s")
      assert Formula.parse("m | s | kg") == {:error, "invalid formula 'm | s | kg'"}
    end

    test "rejects an empty denominator and a leading |" do
      assert Formula.parse("m |") == {:error, "invalid formula 'm |'"}
      assert Formula.parse("| s") == {:error, "invalid formula '| s'"}
    end

    test "rejects parentheses" do
      assert Formula.parse("(m * m)^2") == {:error, "invalid formula '(m * m)^2'"}
      assert Formula.parse("m | (s * s)") == {:error, "invalid formula 'm | (s * s)'"}
    end

    test "rejects a non-integer exponent" do
      assert Formula.parse("s^2.5") == {:error, "invalid formula 's^2.5'"}
    end

    test "rejects a unit-valued exponent" do
      assert Formula.parse("s^m") == {:error, "invalid formula 's^m'"}
    end

    test "rejects a zero exponent" do
      assert Formula.parse("m^0") == {:error, "invalid formula 'm^0'"}
      assert Formula.parse("m^-0") == {:error, "invalid formula 'm^-0'"}
      assert Formula.parse("m^0 * s") == {:error, "invalid formula 'm^0 * s'"}
    end

    test "rejects a leading-zero exponent" do
      assert Formula.parse("m^01") == {:error, "invalid formula 'm^01'"}
      assert Formula.parse("m^-01") == {:error, "invalid formula 'm^-01'"}
    end

    test "rejects a formula that cancels to nothing" do
      assert Formula.parse("m | m") == {:error, "invalid formula 'm | m'"}
      assert Formula.parse("m^2 | m^2") == {:error, "invalid formula 'm^2 | m^2'"}
    end
  end
end
