defmodule Elex.Units.ArithmeticTest do
  use ExUnit.Case, async: true

  alias Elex.{Context, Evaluator, Parser, Unit}
  alias Elex.Units.Catalog

  describe "validate/2 unit literals" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "returns the unit's dimension, not a category atom", %{ctx: ctx} do
      assert Elex.validate("1mm", ctx) == {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "returns :decimal for a unitless number when a catalog is attached", %{ctx: ctx} do
      assert Elex.validate("1", ctx) == {:ok, :decimal}
    end
  end

  describe "validate/2 arithmetic mixing" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")
      {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
      {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "same-category addition is the length dimension", %{ctx: ctx} do
      assert {:ok, dim} = Elex.validate("1m + 1mm", ctx)
      assert dim == %Elex.Dimension{monomial: %{length: 1}}
      assert inspect(dim) == "#Elex.Dimension<length>"
    end

    test "rejects adding a unit and a number", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("1m + 2", ctx)
      assert message == "cannot add length and number"
    end

    test "rejects adding a number and a unit", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("2 + 3m", ctx)
      assert message == "cannot add number and length"
    end

    test "rejects adding zero to a unit", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("1m + 0", ctx)
      assert message == "cannot add length and number"
    end

    test "adds a unitful zero of the same category", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1m + 0m", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "rejects subtracting a unit from a number", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("2 - 1m", ctx)
      assert message == "cannot subtract length from number"
    end

    test "rejects subtracting a number from a unit", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("1m - 2", ctx)
      assert message == "cannot subtract number from length"
    end

    test "unregistered reciprocal dimension is valid", %{ctx: ctx} do
      assert {:ok, dim} = Elex.validate("1 / 1m", ctx)
      assert dim == %Elex.Dimension{monomial: %{length: -1}}
      assert inspect(dim) == "#Elex.Dimension<1 | length>"
    end

    test "rejects adding different categories", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("1m + 1kg", ctx)
      assert message == "cannot add length and mass"
    end

    test "dimensionless times a unit is the unit's dimension", %{ctx: ctx} do
      assert Elex.validate("2 * 3m", ctx) == {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "same-category division cancels to decimal", %{ctx: ctx} do
      assert Elex.validate("4m / 2m", ctx) == {:ok, :decimal}
    end

    test "same-category comparison is boolean", %{ctx: ctx} do
      assert Elex.validate("1m > 10cm", ctx) == {:ok, :boolean}
    end

    test "rejects comparing a unit and a dimensionless number", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("1m > 5", ctx)
      assert message == "cannot compare length and number"
    end

    test "comparing a quantity to literal 0 is boolean", %{ctx: ctx} do
      assert Elex.validate("10cm > 0", ctx) == {:ok, :boolean}
    end

    test "rejects comparing a quantity to a computed zero", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("10cm > (1 - 1)", ctx)
      assert message == "cannot compare length and number"
    end

    test "category: :length on 1m * 1m errors that length was expected", %{ctx: ctx} do
      assert {:error, message} = Elex.validate("1m * 1m", ctx, category: :length)
      assert message == "length was expected, got length^2"
    end

    test "rejects unit: as an unknown option", %{ctx: ctx} do
      assert_raise ArgumentError,
                   "unknown option :unit (use evaluate/3 to convert a result)",
                   fn ->
                     Elex.validate("1m", ctx, unit: "mm")
                   end
    end
  end

  describe "validate/3 without a catalog" do
    test "category: raises when the context has no units catalog" do
      ctx = Elex.new_context()

      assert_raise ArgumentError, "category: requires a units catalog", fn ->
        Elex.validate("1 + 2", ctx, category: :length)
      end
    end

    test "evaluate category: raises when the context has no units catalog" do
      ctx = Elex.new_context()

      assert_raise ArgumentError, "category: requires a units catalog", fn ->
        Elex.evaluate("1 + 2", ctx, category: :length)
      end
    end
  end

  describe "evaluate/2 left-to-right" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "ft", "value * 0.3048")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "adds same-category units into the left unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1m + 1mm", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1.001")) == :eq
    end

    test "adds feet into metres", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1m + 1ft", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1.3048")) == :eq
    end

    test "zero times a unit is zero of that unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("0 * 1m", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("0")) == :eq
    end

    test "compares a quantity to literal 0", %{ctx: ctx} do
      assert Elex.evaluate("10cm > 0", ctx) == {:ok, true}
      assert Elex.evaluate("10cm > 0.0", ctx) == {:ok, true}
      assert Elex.evaluate("10cm > -0", ctx) == {:ok, true}
    end

    test "evaluates scientific notation with a unit suffix", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1e3mm", ctx)
      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1000")) == :eq
    end

    test "keeps the left unit when adding the other way around", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1mm + 1m", ctx)
      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1001")) == :eq
    end

    test "scales a unit by a dimensionless factor", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("2 * 3m", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("6")) == :eq
    end

    test "cancels same-category division to a decimal", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("4m / 2m", ctx)
      assert Decimal.compare(result, Decimal.new("2")) == :eq
    end

    test "cancels 1m / 1m to one", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("1m / 1m", ctx)
      assert Decimal.compare(result, Decimal.new("1")) == :eq
    end

    test "returns an error instead of crashing when adding a quantity and a number", %{ctx: ctx} do
      {:ok, ast, _} = Parser.parse("1m + 1", ctx, validate: false)

      assert Evaluator.evaluate(ast, ctx) == {:error, "cannot add length and number"}
    end

    test "returns an error instead of crashing when subtracting a quantity from a number", %{
      ctx: ctx
    } do
      {:ok, ast, _} = Parser.parse("1 - 1m", ctx, validate: false)

      assert Evaluator.evaluate(ast, ctx) == {:error, "cannot subtract length from number"}
    end

    test "returns an error instead of crashing when subtracting a number from a quantity", %{
      ctx: ctx
    } do
      {:ok, ast, _} = Parser.parse("1m - 1", ctx, validate: false)

      assert Evaluator.evaluate(ast, ctx) == {:error, "cannot subtract number from length"}
    end

    test "divides a length by a unitful zero", %{ctx: ctx} do
      assert Elex.evaluate("1m / 0m", ctx) == {:error, "division by zero"}
    end

    test "divides a unitful zero by a length", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("0m / 1m", ctx)
      assert Decimal.compare(result, Decimal.new("0")) == :eq
    end

    test "negates a length", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("-1m", ctx)
      assert %Unit{monomial: %{"m" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("-1")) == :eq
    end

    test "reports division by zero for a quantity", %{ctx: ctx} do
      assert Elex.evaluate("1m / 0", ctx) == {:error, "division by zero"}
    end

    test "converts before cancelling mixed units of the same category", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("1m / 10cm", ctx)
      assert Decimal.compare(result, Decimal.new("10")) == :eq
    end
  end

  describe "evaluate/3 target unit" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      {:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
      {:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "converts the result into the target unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m + 1mm", ctx, unit: "mm")

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1001")) == :eq
    end

    test "rejects a target unit of a different category", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m + 1mm", ctx, unit: "kg")
      assert message == "expression should return a valid mass result"
    end

    test "rejects an unknown target unit", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m + 1mm", ctx, unit: "foo")
      assert message == "unknown unit 'foo'"
    end

    test "rejects a target unit when the result is dimensionless", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1 + 1", ctx, unit: "mm")
      assert message == "cannot convert number to a unit"
    end

    test "rejects a target unit when the result is a comparison", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m > 1mm", ctx, unit: "mm")
      assert message == "cannot convert yes/no to a unit"
    end

    test "rejects a target unit when the result is text", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(~s["hi"], ctx, unit: "mm")
      assert message == "cannot convert text to a unit"
    end

    test "rejects an empty target unit", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m", ctx, unit: "")
      assert message == "unit is empty"
    end

    test "rejects a whitespace-only target unit", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m", ctx, unit: "  ")
      assert message == "unit is empty"
    end

    test "category: rejects an incompatible evaluate result", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m * 1m", ctx, category: :length)
      assert message == "length was expected, got length^2"
    end

    test "category: accepts a compatible evaluate result", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{unit: unit}} =
               Elex.evaluate("1m + 1mm", ctx, category: :length)

      assert %Unit{monomial: %{"m" => 1}} = unit
    end

    test "applies unit: together with a matching category:", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m + 1mm", ctx, unit: "mm", category: :length)

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1001")) == :eq
    end

    test "rejects an unknown evaluate option", %{ctx: ctx} do
      assert_raise ArgumentError, "unknown option :bogus", fn ->
        Elex.evaluate("1m", ctx, bogus: true)
      end
    end

    test "rejects a cancelled formula target", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m", ctx, unit: "m | m")
      assert message == "invalid formula 'm | m'"
    end

    test "rejects a same-category formula target", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m", ctx, unit: "m | mm")

      assert message ==
               "formula 'm | mm' repeats category :length in the numerator and denominator"
    end

    test "rejects a dimensionless formula target", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m", ctx, unit: "m^0")
      assert message == "invalid formula 'm^0'"
    end

    test "rejects a formula target that cancels through exponents", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m / 1m", ctx, unit: "m * m^-1")
      assert message == "invalid formula 'm * m^-1'"
    end

    test "hints at | when unit: uses slash division", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m", ctx, unit: "km / h")

      assert message ==
               "invalid formula 'km / h'; use '|' for division (m | s, km | h), not '/'"
    end

    test "hints that braces are not valid in unit:", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("1m", ctx, unit: "{m}")

      assert message ==
               "invalid formula '{m}'; braces belong on a quantity suffix (1 {m | s}), not in unit: or convert"
    end
  end

  describe "evaluate/2 leftover unit after cancel" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "keeps leftover millimetres after cancelling time", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("(1mm / 1s) * 1s", ctx)

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "cancelling then dividing again leaves a reciprocal leftover", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1m / 1m / 1m", ctx)
      assert %Unit{monomial: %{"m" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "re-units after a dimensionless intermediate from left-associative cancel", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("1m / 1mm * 1mm", ctx)

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("1000")) == :eq
    end

    test "a power suffix is five square metres, not the square of five metres", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: suffix, unit: suffix_unit}} = Elex.evaluate("5m^2", ctx)

      assert {:ok, %Elex.Quantity{value: product, unit: product_unit}} =
               Elex.evaluate("5m * 5m", ctx)

      assert %Unit{monomial: %{"m" => 2}} = suffix_unit
      assert Unit.same?(suffix_unit, product_unit)
      assert Decimal.compare(suffix, Decimal.new("5")) == :eq
      assert Decimal.compare(product, Decimal.new("25")) == :eq
    end

    test "treats 10m/s as metres divided by variable s, unlike 10m / 1s", %{ctx: ctx} do
      assert Elex.evaluate("10m/s", ctx) == {:error, "variable 's' does not exist"}

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("10m / 1s", ctx)
      assert %Unit{monomial: %{"m" => 1, "s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("10")) == :eq
    end
  end

  describe "evaluate/2 dual symbols of the same category" do
    test "adds hour and h into the left unit" do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "hour", "value * 3600")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "h", "value * 3600")
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1hour + 1h", ctx)
      assert %Unit{monomial: %{"hour" => 1}} = unit
      assert Decimal.compare(value, Decimal.new("2")) == :eq
    end
  end

  describe "evaluate/2 overlapping same-category factors" do
    setup do
      {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
      {:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
      {:ok, catalog} = Catalog.add_unit(catalog, :time, "s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area, formula: "length * length", default: "m * m")

      {:ok, catalog} = Catalog.add_unit(catalog, :area, "m * m", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :area_rate,
          formula: "length * length | time",
          default: "m * m | s"
        )

      {:ok, catalog} = Catalog.add_unit(catalog, :area_rate, "m * m | s", "value")

      {:ok, catalog} =
        Catalog.add_category(catalog, :frequency, formula: "time^-1", default: "s^-1")

      {:ok, catalog} = Catalog.add_unit(catalog, :frequency, "s^-1", "value")

      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
      %{ctx: ctx}
    end

    test "multiplies mixed units of the same category into the left unit", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1m * 1mm", ctx)
      assert %Unit{monomial: %{"m" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("0.001")) == :eq
    end

    test "keeps the left unit when multiplying the other way around", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1mm * 1m", ctx)
      assert %Unit{monomial: %{"mm" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("1000")) == :eq
    end

    test "keeps matching units when multiplying the same symbol", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate("1mm * 1mm", ctx)
      assert %Unit{monomial: %{"mm" => 2}} = unit
      assert Decimal.compare(value, Decimal.new("1")) == :eq
    end

    test "converts overlapping length when multiplying into a quotient", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("(1m / 1s) * 1mm", ctx)

      assert %Unit{monomial: %{"m" => 2, "s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("0.001")) == :eq
    end

    test "converts overlapping length when dividing a quotient", %{ctx: ctx} do
      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("(1m / 1s) / 1mm", ctx)

      assert %Unit{monomial: %{"s" => -1}} = unit
      assert Decimal.compare(value, Decimal.new("1000")) == :eq
    end
  end

  describe "evaluate/2 conversion arithmetic errors" do
    test "reports division by zero inside a conversion" do
      {:ok, catalog} =
        Catalog.add_category(Catalog.new(), :length, default: "m", additive: false)

      {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
      {:ok, catalog} = Catalog.add_unit(catalog, :length, "recip", "1 / (value + 1)")
      {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)

      assert Elex.evaluate("-1recip", ctx, unit: "m") ==
               {:error, "division by zero"}
    end
  end
end
