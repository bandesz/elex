defmodule Elex.PercentCompareTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Units.Catalog

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "percent comparisons" do
    test "orders a larger percent above a smaller one", %{ctx: ctx} do
      assert Elex.evaluate("50% > 10%", ctx) == {:ok, true}
    end

    test "orders a positive percent above zero percent", %{ctx: ctx} do
      assert Elex.evaluate("10% > 0%", ctx) == {:ok, true}
    end

    test "orders a negative percent below zero percent", %{ctx: ctx} do
      assert Elex.evaluate("-10% < 0%", ctx) == {:ok, true}
    end

    test "treats equal percents as equal", %{ctx: ctx} do
      assert Elex.evaluate("50% == 50%", ctx) == {:ok, true}
    end

    test "compares a percent greater than literal zero", %{ctx: ctx} do
      assert Elex.evaluate("100% > 0", ctx) == {:ok, true}
    end

    test "compares literal zero less than a percent", %{ctx: ctx} do
      assert Elex.evaluate("0 < 100%", ctx) == {:ok, true}
    end

    test "treats zero percent as equal to literal zero", %{ctx: ctx} do
      assert Elex.evaluate("0% == 0", ctx) == {:ok, true}
    end

    test "does not treat a non-zero percent as equal to literal zero", %{ctx: ctx} do
      assert Elex.evaluate("100% == 0", ctx) == {:ok, false}
    end

    test "treats other zero spellings as literal zero next to a percent", %{ctx: ctx} do
      for zero <- ["0.0", "0.00", "0e0", "-0", "(0)", "--0"] do
        assert Elex.evaluate("100% > #{zero}", ctx) == {:ok, true}
      end
    end

    test "validates a percent compared with literal zero as boolean", %{ctx: ctx} do
      assert Elex.validate("100% > 0", ctx) == {:ok, :boolean}
    end

    test "orders percents with the remaining comparison operators", %{ctx: ctx} do
      assert Elex.evaluate("10% <= 50%", ctx) == {:ok, true}
      assert Elex.evaluate("50% >= 10%", ctx) == {:ok, true}
      assert Elex.evaluate("50% != 10%", ctx) == {:ok, true}
      assert Elex.evaluate("100% != 0", ctx) == {:ok, true}
      assert Elex.evaluate("0% <= 0", ctx) == {:ok, true}
    end
  end

  describe "percent comparison errors" do
    test "rejects comparing a percent with a non-zero number", %{ctx: ctx} do
      assert_type_error("100% > 1", "cannot compare percent and number", ctx)
    end

    test "rejects comparing a percent with a fractional number", %{ctx: ctx} do
      assert_type_error("50% == 0.5", "cannot compare percent and number", ctx)
    end

    test "rejects comparing a percent with a length" do
      assert_type_error("50% > 10cm", "cannot compare percent and length", length_context())
    end

    test "rejects comparing a percent with a decimal variable", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "count", 1)
      assert_type_error("100% > count", "cannot compare percent and number", ctx)
    end

    test "rejects comparing a percent with a zero-valued decimal variable", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "count", 0)
      assert_type_error("100% > count", "cannot compare percent and number", ctx)
    end

    test "rejects comparing a percent with a computed zero", %{ctx: ctx} do
      assert_type_error("100% > (1 - 1)", "cannot compare percent and number", ctx)
    end
  end

  defp assert_type_error(expression, message, ctx) do
    assert Elex.validate(expression, ctx) == {:error, message}
    assert Elex.evaluate(expression, ctx) == {:error, message}
  end

  defp length_context do
    {:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
    {:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")

    {:ok, ctx} = Context.put_units(Elex.new_context(), catalog)
    ctx
  end
end
