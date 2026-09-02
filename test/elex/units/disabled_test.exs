defmodule Elex.Units.DisabledTest do
  use ExUnit.Case, async: true

  describe "units off (default)" do
    setup do
      %{ctx: Elex.new_context()}
    end

    test "evaluates unitless arithmetic", %{ctx: ctx} do
      assert {:ok, result} = Elex.evaluate("1 + 2", ctx)
      assert Decimal.equal?(result, Decimal.new("3"))
    end

    test "validates a unitless expression", %{ctx: ctx} do
      {:ok, ctx} = Elex.add_variable(ctx, "x", 10)
      assert Elex.validate("x + 1", ctx) == {:ok, :decimal}
    end

    test "rejects a glued unit-like token as unexpected", %{ctx: ctx} do
      assert Elex.evaluate("1cm", ctx) == {:error, "unexpected 'cm'"}
    end

    test "rejects a spaced unit-like token as unexpected", %{ctx: ctx} do
      assert Elex.evaluate("1 cm", ctx) == {:error, "unexpected 'cm'"}
    end

    test "rejects a unit-like token after addition as unexpected", %{ctx: ctx} do
      {:ok, ctx} = Elex.add_variable(ctx, "width", 10)
      assert Elex.evaluate("width + 2mm", ctx) == {:error, "unexpected 'mm'"}
    end

    test "extract_variables reports an unexpected token, not a missing operand", %{ctx: ctx} do
      assert Elex.extract_variables("width + 2mm", ctx) == {:error, "unexpected 'mm'"}
    end
  end
end
