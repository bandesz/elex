defmodule Elex.PercentPowTest do
  use ExUnit.Case, async: true

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "percent pow and sqrt" do
    test "squares a percent on the fraction", %{ctx: ctx} do
      assert_percent("pow(50%, 2)", "25", ctx)
    end

    test "cubes a percent on the fraction", %{ctx: ctx} do
      assert_percent("pow(50%, 3)", "12.5", ctx)
    end

    test "even integer power of a negative percent is positive", %{ctx: ctx} do
      assert_percent("pow(-50%, 2)", "25", ctx)
    end

    test "odd integer power of a negative percent stays negative", %{ctx: ctx} do
      assert_percent("pow(-50%, 3)", "-12.5", ctx)
    end

    test "zero exponent of a percent is 100 percent", %{ctx: ctx} do
      assert_percent("pow(50%, 0)", "100", ctx)
      assert_percent("pow(0%, 0)", "100", ctx)
    end

    test "raising a percent to the first power keeps it", %{ctx: ctx} do
      assert_percent("pow(50%, 1)", "50", ctx)
    end

    test "negative integer exponent inverts the fraction", %{ctx: ctx} do
      assert_percent("pow(50%, -1)", "200", ctx)
    end

    test "non-integer power scales the decimal power back to points", %{ctx: ctx} do
      assert {:ok, powered} = Elex.evaluate("pow(0.5, 0.5)", ctx)
      expected = Decimal.mult(powered, Decimal.new(100))

      assert {:ok, %Elex.Percent{value: points}} = Elex.evaluate("pow(50%, 0.5)", ctx)
      assert Decimal.equal?(points, expected)
    end

    test "validates a power of a percent as percent", %{ctx: ctx} do
      assert Elex.validate("pow(50%, 2)", ctx) == {:ok, :percent}
    end
  end

  describe "percent pow and sqrt errors" do
    test "rejects a percent exponent", %{ctx: ctx} do
      message = "pow function expects a number exponent, got percent"

      assert_type_error("pow(2, 50%)", message, ctx)
      assert_type_error("pow(50%, 50%)", message, ctx)
    end

    test "negative exponent of zero percent matches decimal zero", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate("pow(0, -1)", ctx)
      assert Elex.evaluate("pow(0%, -1)", ctx) == {:error, message}
    end

    test "rejects a percent square root", %{ctx: ctx} do
      message = "sqrt function expects a number argument, got percent"

      assert_type_error("sqrt(25%)", message, ctx)
      assert_type_error("sqrt(0%)", message, ctx)
      assert_type_error("sqrt(50%)", message, ctx)
      assert_type_error("sqrt(-25%)", message, ctx)
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
