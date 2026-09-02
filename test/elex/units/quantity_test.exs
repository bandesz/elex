defmodule Elex.Units.QuantityTest do
  use ExUnit.Case, async: true

  alias Elex.Quantity
  alias Elex.Unit

  describe "inspect/1" do
    test "pretty-prints a quantity with an Elex.Unit symbol" do
      qty = %Quantity{
        value: Decimal.new("1.001"),
        unit: Unit.from_monomial(%{"m" => 1})
      }

      assert %Quantity{unit: %Unit{}} = qty
      assert inspect(qty) == "#Elex.Quantity<1.001 m>"
    end

    test "pretty-prints a quantity with an Elex.Unit monomial" do
      qty = %Quantity{
        value: Decimal.new("10"),
        unit: Unit.new!(%{"m" => 1, "s" => -1})
      }

      assert inspect(qty) == "#Elex.Quantity<10 m | s>"
    end

    test "pretty-prints a squared monomial with a caret" do
      qty = %Quantity{value: Decimal.new("4"), unit: Unit.new!(%{"m" => 2})}

      assert inspect(qty) == "#Elex.Quantity<4 m^2>"
    end

    test "pretty-prints a squared denominator with a caret" do
      qty = %Quantity{value: Decimal.new("10"), unit: Unit.new!(%{"m" => 1, "s" => -2})}

      assert inspect(qty) == "#Elex.Quantity<10 m | s^2>"
    end

    test "pretty-prints a named force unit as N" do
      qty = %Quantity{value: Decimal.new("1"), unit: Unit.from_monomial(%{"N" => 1})}

      assert inspect(qty) == "#Elex.Quantity<1 N>"
    end

    test "pretty-prints a reciprocal leftover without a leading space" do
      qty = %Quantity{value: Decimal.new("1"), unit: Unit.from_monomial(%{"m" => -1})}

      assert inspect(qty) == "#Elex.Quantity<1 | m>"
    end

    test "drops trailing zeros from the magnitude" do
      qty = %Quantity{value: Decimal.new("36.0000"), unit: Unit.new!("km | h")}

      assert inspect(qty) == "#Elex.Quantity<36 km | h>"
    end
  end
end
