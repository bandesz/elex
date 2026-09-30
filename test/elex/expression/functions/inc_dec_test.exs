defmodule Elex.Functions.IncDecTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Function
  alias Elex.Units.Catalog
  alias Elex.Units.Temperature

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "inc/2 and dec/2" do
    test "increases and decreases a number by a percent", %{ctx: ctx} do
      assert_decimal("inc(100, 10%)", "110", ctx)
      assert_decimal("dec(100, 10%)", "90", ctx)
      assert_decimal("inc(-100, 10%)", "-110", ctx)
    end

    test "a negative rate reverses the direction", %{ctx: ctx} do
      assert_decimal("inc(100, -10%)", "90", ctx)
      assert_decimal("dec(100, -10%)", "110", ctx)
    end

    test "does not clamp a rate outside 0 to 100", %{ctx: ctx} do
      assert_decimal("dec(100, 150%)", "-50", ctx)
      assert_decimal("inc(100, 0%)", "100", ctx)
      assert_decimal("dec(100, 100%)", "0", ctx)
    end

    test "scales a percent and keeps a percent", %{ctx: ctx} do
      assert_percent("inc(50%, 10%)", "55", ctx)
      assert_percent("dec(50%, 10%)", "45", ctx)
    end

    test "scales a length and keeps the unit" do
      ctx = length_context()
      assert_quantity("inc(100cm, 10%)", "110", "cm", ctx)
      assert_quantity("dec(100cm, 10%)", "90", "cm", ctx)

      assert {:ok, %Elex.Quantity{value: value, unit: unit}} =
               Elex.evaluate("inc(100cm, 10%)", ctx, unit: "mm")

      assert %Elex.Unit{monomial: %{"mm" => 1}} = unit
      assert Decimal.equal?(value, Decimal.new("1100"))
    end

    test "scales variables", %{ctx: ctx} do
      ctx =
        ctx
        |> Elex.add_variable!("price", 100)
        |> Elex.add_variable!("rate", %Elex.Percent{value: Decimal.new("10")})

      assert_decimal("inc(price, rate)", "110", ctx)
      assert_decimal("dec(price, rate)", "90", ctx)
    end

    test "scales a float variable by a percent rate", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "price", 100.0)

      assert_decimal("inc(price, 10%)", "110", ctx)
      assert_decimal("dec(price, 10%)", "90", ctx)
    end

    test "types follow the value", %{ctx: ctx} do
      assert Elex.validate("inc(100, 10%)", ctx) == {:ok, :decimal}
      assert Elex.validate("dec(50%, 10%)", ctx) == {:ok, :percent}

      assert Elex.validate("inc(100cm, 10%)", length_context()) ==
               {:ok, %Elex.Dimension{monomial: %{length: 1}}}
    end

    test "rejects a rate that is not a percent", %{ctx: ctx} do
      assert {:error, "inc function expects a percent rate, got decimal"} =
               Elex.evaluate("inc(100, 10)", ctx)

      assert {:error, "dec function expects a percent rate, got decimal"} =
               Elex.evaluate("dec(100, 0)", ctx)

      assert {:error, "inc function expects a percent rate, got length quantity"} =
               Elex.validate("inc(100, 10cm)", length_context())
    end

    test "rejects a non-numeric value before checking the rate", %{ctx: ctx} do
      assert {:error, "inc function expects a number argument, got string"} =
               Elex.evaluate("inc(\"a\", 10)", ctx)

      assert {:error, "dec function expects a number argument, got empty"} =
               Elex.evaluate("dec(null, 10%)", ctx)
    end

    test "rejects a non-additive quantity and reports a bad rate first" do
      {:ok, ctx} = Context.put_units(Elex.new_context(), Temperature.catalog())

      assert {:error, "cannot use non-additive temperature with 'inc'"} =
               Elex.validate("inc(20C, 10%)", ctx)

      assert {:error, "inc function expects a percent rate, got decimal"} =
               Elex.validate("inc(20C, 10)", ctx)
    end

    test "propagates a missing variable", %{ctx: ctx} do
      assert {:error, "variable 'price' does not exist"} = Elex.evaluate("inc(price, 10%)", ctx)
    end

    test "expects two arguments", %{ctx: ctx} do
      assert {:error, "inc function expects 2 arguments"} = Elex.evaluate("inc(100)", ctx)
    end
  end

  describe "documentation/0" do
    test "documents both functions as math" do
      assert Function.units(Elex.Functions.Inc) == :additive
      assert Function.units(Elex.Functions.Dec) == :additive

      assert Elex.Functions.Inc.documentation() == %{
               signature: "inc(value, rate)",
               description: "returns value increased by a percent rate",
               category: :math
             }

      assert Elex.Functions.Dec.documentation() == %{
               signature: "dec(value, rate)",
               description: "returns value decreased by a percent rate",
               category: :math
             }
    end
  end

  defp assert_decimal(expression, expected, ctx) do
    assert {:ok, %Decimal{} = value} = Elex.evaluate(expression, ctx)
    assert Decimal.equal?(value, Decimal.new(expected))
  end

  defp assert_percent(expression, expected, ctx) do
    assert {:ok, %Elex.Percent{value: value}} = Elex.evaluate(expression, ctx)
    assert Decimal.equal?(value, Decimal.new(expected))
  end

  defp assert_quantity(expression, expected, symbol, ctx) do
    assert {:ok, %Elex.Quantity{value: value, unit: unit}} = Elex.evaluate(expression, ctx)
    assert %Elex.Unit{monomial: %{^symbol => 1}} = unit
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
