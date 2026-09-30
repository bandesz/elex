defmodule Elex.PercentVariableTest do
  use ExUnit.Case, async: true

  alias Elex.Variable

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "percent variables" do
    test "stores a percent variable as type percent", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "rate", %Elex.Percent{value: Decimal.new("50")})

      assert %Variable{type: :percent, value: %Elex.Percent{value: value}} = ctx.variables["rate"]
      assert Decimal.equal?(value, Decimal.new("50"))
    end

    test "scales a number by a percent variable", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "rate", %Elex.Percent{value: Decimal.new("50")})

      assert {:ok, %Decimal{} = value} = Elex.evaluate("100 * rate", ctx)
      assert Decimal.equal?(value, Decimal.new("50"))
    end

    test "adds a percent literal to a percent variable", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "rate", %Elex.Percent{value: Decimal.new("50")})

      assert {:ok, %Elex.Percent{value: value}} = Elex.evaluate("rate + 10%", ctx)
      assert Decimal.equal?(value, Decimal.new("60"))
    end

    test "validates a percent variable as percent", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "rate", %Elex.Percent{value: Decimal.new("50")})

      assert Elex.validate("rate", ctx) == {:ok, :percent}
    end

    test "keeps an integer variable as a number", %{ctx: ctx} do
      ctx = Elex.add_variable!(ctx, "rate", 50)

      assert %Variable{type: :decimal, value: 50} = ctx.variables["rate"]
      assert {:ok, %Decimal{} = value} = Elex.evaluate("100 * rate", ctx)
      assert Decimal.equal?(value, Decimal.new("5000"))
    end
  end

  describe "percent variable errors" do
    test "rejects a percent whose value is an integer", %{ctx: ctx} do
      assert Elex.add_variable(ctx, "rate", %Elex.Percent{value: 50}) ==
               {:error, "variable 'rate' percent value must be a decimal"}
    end

    test "rejects a percent variable with a category", %{ctx: ctx} do
      assert Elex.add_variable(ctx, "rate", %Elex.Percent{value: Decimal.new("50")},
               category: :length
             ) ==
               {:error, "variable 'rate' has category length but value is unitless"}
    end
  end
end
