defmodule Elex.PercentRoundTest do
  use ExUnit.Case, async: true

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "percent abs, round, floor, and ceil" do
    test "abs of a negative percent is the positive percent", %{ctx: ctx} do
      assert_percent("abs(-10%)", "10", ctx)
    end

    test "round of 10.4 percent is 10 percent", %{ctx: ctx} do
      assert_percent("round(10.4%)", "10", ctx)
    end

    test "round of 10.5 percent is 11 percent", %{ctx: ctx} do
      assert_percent("round(10.5%)", "11", ctx)
    end

    test "round of negative 10.5 percent is negative 11 percent", %{ctx: ctx} do
      assert_percent("round(-10.5%)", "-11", ctx)
    end

    test "floor of 10.9 percent is 10 percent", %{ctx: ctx} do
      assert_percent("floor(10.9%)", "10", ctx)
    end

    test "floor of negative 10.1 percent is negative 11 percent", %{ctx: ctx} do
      assert_percent("floor(-10.1%)", "-11", ctx)
    end

    test "ceil of 10.1 percent is 11 percent", %{ctx: ctx} do
      assert_percent("ceil(10.1%)", "11", ctx)
    end

    test "ceil of negative 10.1 percent is negative 10 percent", %{ctx: ctx} do
      assert_percent("ceil(-10.1%)", "-10", ctx)
    end

    test "validates abs of a percent as percent", %{ctx: ctx} do
      assert Elex.validate("abs(-10%)", ctx) == {:ok, :percent}
    end
  end

  describe "percent concat error" do
    test "rejects concat of a percent with a string", %{ctx: ctx} do
      assert_type_error(
        "concat(10%, \"x\")",
        "concat function expects string arguments, got percent",
        ctx
      )
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
end
