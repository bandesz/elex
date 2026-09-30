defmodule Elex.PercentScaleTest do
  use ExUnit.Case, async: true

  alias Elex.{Context, Unit}
  alias Elex.Units.Catalog
  alias Elex.Units.Temperature

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "evaluate/3 percent scale" do
    test "scales a number by a percent in either order", %{ctx: ctx} do
      assert_decimal("100 * 50%", "50", ctx)
      assert_decimal("50% * 100", "50", ctx)
    end

    test "scales an integer variable by a percent in either order", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "x", 10)
      assert_decimal("x * 50%", "5", ctx)
      assert_decimal("50% * x", "5", ctx)
    end

    test "scales a float variable by a percent in either order", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "x", 10.0)
      assert_decimal("x * 50%", "5", ctx)
      assert_decimal("50% * x", "5", ctx)
    end

    test "scales two by fifty percent", %{ctx: ctx} do
      assert_decimal("2 * 50%", "1", ctx)
    end

    test "scales a length by a percent in either order" do
      ctx = length_context()
      assert_quantity("100cm * 50%", "50", "cm", ctx)
      assert_quantity("50% * 100cm", "50", "cm", ctx)
    end

    test "scales a length by a negative percent" do
      ctx = length_context()
      assert_quantity("100cm * -10%", "-10", "cm", ctx)
    end

    test "scales an absolute length by a percent in either order" do
      ctx = length_context()
      assert_quantity("abs(-100cm) * 50%", "50", "cm", ctx)
      assert_quantity("50% * abs(-100cm)", "50", "cm", ctx)
    end

    test "scales a length from add_unit by a percent in either order" do
      ctx = length_context()
      assert_quantity(~S|add_unit(100, "cm") * 50%|, "50", "cm", ctx)
      assert_quantity(~S|50% * add_unit(100, "cm")|, "50", "cm", ctx)
    end

    test "rejects a non-additive temperature times a percent in either order" do
      {:ok, ctx} = Context.put_units(Elex.new_context(), Temperature.catalog())

      assert {:error, "cannot use non-additive temperature with '*' or '/'"} =
               Elex.evaluate("20C * 50%", ctx)

      assert {:error, "cannot use non-additive temperature with '*' or '/'"} =
               Elex.evaluate("50% * 20C", ctx)
    end

    test "rejects a converted non-additive temperature times a percent in either order" do
      {:ok, ctx} = Context.put_units(Elex.new_context(), Temperature.catalog())

      assert {:error, "cannot use non-additive temperature with '*' or '/'"} =
               Elex.evaluate(~S|convert(20C, "F") * 50%|, ctx)

      assert {:error, "cannot use non-additive temperature with '*' or '/'"} =
               Elex.evaluate(~S|50% * convert(20C, "F")|, ctx)
    end

    test "scales a number by successive percents", %{ctx: ctx} do
      assert_decimal("100 * 50% * 50%", "25", ctx)
    end

    test "converts a scaled length into the target unit" do
      ctx = length_context()

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("100cm * 50%", ctx, unit: "mm")

      assert %Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.equal?(value, Decimal.new("500"))
    end
  end

  describe "validate/3 percent scale" do
    test "types a number times a percent as a decimal", %{ctx: ctx} do
      assert Elex.validate("100 * 50%", ctx) == {:ok, :decimal}
    end

    test "types a length times a percent as the length dimension" do
      assert Elex.validate("100cm * 50%", length_context()) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "types an absolute length times a percent as the length dimension" do
      ctx = length_context()

      assert Elex.validate("abs(-100cm) * 50%", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1}}}

      assert Elex.validate("50% * abs(-100cm)", ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "types a length from add_unit times a percent as the length dimension" do
      ctx = length_context()

      assert Elex.validate(~S|add_unit(100, "cm") * 50%|, ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1}}}

      assert Elex.validate(~S|50% * add_unit(100, "cm")|, ctx) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "rejects a non-additive temperature times a percent in either order" do
      {:ok, ctx} = Context.put_units(Elex.new_context(), Temperature.catalog())

      assert {:error, "cannot use non-additive temperature with '*' or '/'"} =
               Elex.validate("20C * 50%", ctx)

      assert {:error, "cannot use non-additive temperature with '*' or '/'"} =
               Elex.validate("50% * 20C", ctx)
    end

    test "rejects a converted non-additive temperature times a percent in either order" do
      {:ok, ctx} = Context.put_units(Elex.new_context(), Temperature.catalog())

      assert {:error, "cannot use non-additive temperature with '*' or '/'"} =
               Elex.validate(~S|convert(20C, "F") * 50%|, ctx)

      assert {:error, "cannot use non-additive temperature with '*' or '/'"} =
               Elex.validate(~S|50% * convert(20C, "F")|, ctx)
    end
  end

  defp assert_decimal(expression, expected, ctx) do
    assert {:ok, %Decimal{} = value} = Elex.evaluate(expression, ctx)
    assert Decimal.equal?(value, Decimal.new(expected))
  end

  defp assert_quantity(expression, expected, symbol, ctx) do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate(expression, ctx)
    assert %Unit{monomial: %{^symbol => 1}} = unit
    assert Decimal.equal?(value, Decimal.new(expected))
  end

  defp length_context do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end
end
