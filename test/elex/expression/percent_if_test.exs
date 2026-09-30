defmodule Elex.PercentIfTest do
  use ExUnit.Case, async: true

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "percent if and coalesce" do
    test "if true returns the first percent", %{ctx: ctx} do
      assert_percent("if(true, 10%, 20%)", "10", ctx)
    end

    test "if false returns the second percent", %{ctx: ctx} do
      assert_percent("if(false, 10%, 20%)", "20", ctx)
    end

    test "if true with a literal zero branch returns the percent", %{ctx: ctx} do
      assert_percent("if(true, 10%, 0)", "10", ctx)
    end

    test "if false with a literal zero branch returns zero percent", %{ctx: ctx} do
      assert_percent("if(false, 10%, 0)", "0", ctx)
    end

    test "if condition comparing a percent to literal zero returns the percent", %{ctx: ctx} do
      assert_percent("if(100% > 0, 100%, 0)", "100", ctx)
    end

    test "coalesce skips null and returns a percent", %{ctx: ctx} do
      assert_percent("coalesce(null, 10%)", "10", ctx)
    end

    test "coalesce returns literal zero as zero percent before a later percent", %{ctx: ctx} do
      assert_percent("coalesce(null, 0, 10%)", "0", ctx)
    end

    test "coalesce returns a percent and ignores a later literal zero", %{ctx: ctx} do
      assert_percent("coalesce(null, 10%, 0)", "10", ctx)
    end

    test "if true skips an unused percent branch that errors only when evaluated", %{ctx: ctx} do
      assert_percent("if(true, 10%, pow(0%, -1))", "10", ctx)
    end

    test "if false skips an unused percent branch that errors only when evaluated", %{ctx: ctx} do
      assert_percent("if(false, pow(0%, -1), 10%)", "10", ctx)
    end
  end

  describe "percent if and coalesce errors" do
    test "rejects if branches that mix a percent with a number", %{ctx: ctx} do
      assert_type_error(
        "if(true, 10%, 1)",
        "if branches must have the same type, got percent and number",
        ctx
      )
    end

    test "rejects if that mixes a percent with division by zero", %{ctx: ctx} do
      assert_type_error(
        "if(true, 10%, 1 / 0)",
        "if branches must have the same type, got percent and number",
        ctx
      )
    end

    test "rejects coalesce arguments that mix a percent with a number", %{ctx: ctx} do
      assert_type_error(
        "coalesce(10%, 1)",
        "coalesce arguments must have the same type, got percent and number",
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
