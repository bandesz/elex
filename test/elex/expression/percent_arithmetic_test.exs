defmodule Elex.PercentArithmeticTest do
  use ExUnit.Case, async: true

  alias Elex.Context
  alias Elex.Units.Catalog

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "evaluate/3 percent arithmetic" do
    test "adds percent points", %{ctx: ctx} do
      assert_percent("10% + 20%", "30", ctx)
    end

    test "subtracts percent points", %{ctx: ctx} do
      assert_percent("30% - 20%", "10", ctx)
    end

    test "subtracts to a negative percent", %{ctx: ctx} do
      assert_percent("20% - 30%", "-10", ctx)
    end

    test "adds a negative percent", %{ctx: ctx} do
      assert_percent("100% + -10%", "90", ctx)
    end

    test "multiplies percents as points over one hundred", %{ctx: ctx} do
      assert_percent("50% * 50%", "25", ctx)
    end

    test "multiplies three percents left to right", %{ctx: ctx} do
      assert_percent("50% * 50% * 50%", "12.5", ctx)
    end
  end

  describe "validate/3 percent arithmetic" do
    test "types percent addition as a percent", %{ctx: ctx} do
      assert Elex.validate("10% + 20%", ctx) == {:ok, :percent}
    end

    test "types percent multiplication as a percent", %{ctx: ctx} do
      assert Elex.validate("50% * 50%", ctx) == {:ok, :percent}
    end
  end

  describe "percent arithmetic errors" do
    test "rejects adding a percent and a number", %{ctx: ctx} do
      assert_type_error("10% + 1", "cannot add percent and number", ctx)
      assert_type_error("1 + 10%", "cannot add number and percent", ctx)
    end

    test "rejects adding a length and a percent" do
      ctx = length_context()
      assert_type_error("100cm + 50%", "cannot add length and percent", ctx)
      assert_type_error("50% + 100cm", "cannot add percent and length", ctx)
    end

    test "rejects subtracting a percent and a number", %{ctx: ctx} do
      assert_type_error("10% - 1", "cannot subtract number from percent", ctx)
      assert_type_error("1 - 10%", "cannot subtract percent from number", ctx)
    end

    test "rejects subtracting a length and a percent" do
      ctx = length_context()
      assert_type_error("100cm - 50%", "cannot subtract length and percent", ctx)
      assert_type_error("50% - 100cm", "cannot subtract percent and length", ctx)
    end

    test "rejects adding a literal zero and a percent", %{ctx: ctx} do
      assert_type_error("10% + 0", "cannot add percent and number", ctx)
      assert_type_error("0 + 10%", "cannot add number and percent", ctx)
    end

    test "rejects dividing a percent and a number", %{ctx: ctx} do
      assert_type_error("100% / 2", "cannot divide with a percent", ctx)
      assert_type_error("2 / 100%", "cannot divide with a percent", ctx)
    end

    test "rejects dividing two percents", %{ctx: ctx} do
      assert_type_error("100% / 50%", "cannot divide with a percent", ctx)
    end

    test "rejects dividing a length and a percent" do
      ctx = length_context()
      assert_type_error("100cm / 50%", "cannot divide with a percent", ctx)
      assert_type_error("50% / 100cm", "cannot divide with a percent", ctx)
    end
  end

  defp assert_percent(expression, expected, ctx) do
    assert {:ok, %Elex.Percent{value: value}} = Elex.evaluate(expression, ctx)
    assert Decimal.equal?(value, Decimal.new(expected))
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
