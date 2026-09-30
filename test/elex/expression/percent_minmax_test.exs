defmodule Elex.PercentMinmaxTest do
  use ExUnit.Case, async: true

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "percent min, max, clamp, and between" do
    test "min of percents returns the smallest percent", %{ctx: ctx} do
      assert_percent("min(30%, 10%, 20%)", "10", ctx)
    end

    test "max of percents returns the largest percent", %{ctx: ctx} do
      assert_percent("max(30%, 10%)", "30", ctx)
    end

    test "clamp limits a percent to the upper bound", %{ctx: ctx} do
      assert_percent("clamp(150%, 0%, 100%)", "100", ctx)
    end

    test "clamp limits a negative percent to the lower bound", %{ctx: ctx} do
      assert_percent("clamp(-150%, -100%, 0%)", "-100", ctx)
    end

    test "min of a percent and literal zero is zero percent", %{ctx: ctx} do
      assert_percent("min(10%, 0)", "0", ctx)
    end

    test "min of literal zero and a percent is zero percent", %{ctx: ctx} do
      assert_percent("min(0, 10%)", "0", ctx)
    end

    test "max of a percent and literal zero is the percent", %{ctx: ctx} do
      assert_percent("max(10%, 0)", "10", ctx)
    end

    test "clamp of a negative percent against literal zero is zero percent", %{ctx: ctx} do
      assert_percent("clamp(-5%, 0, 100%)", "0", ctx)
    end

    test "between is true when a percent is inside the range", %{ctx: ctx} do
      assert Elex.evaluate("between(15%, 10%, 20%)", ctx) == {:ok, true}
    end

    test "between is true when a percent equals the lower bound", %{ctx: ctx} do
      assert Elex.evaluate("between(10%, 10%, 20%)", ctx) == {:ok, true}
    end

    test "between is false when a percent is below the range", %{ctx: ctx} do
      assert Elex.evaluate("between(9%, 10%, 20%)", ctx) == {:ok, false}
    end

    test "between accepts literal zero as a percent bound", %{ctx: ctx} do
      assert Elex.evaluate("between(5%, 0, 100%)", ctx) == {:ok, true}
    end

    test "validates min of percents as percent", %{ctx: ctx} do
      assert Elex.validate("min(30%, 10%)", ctx) == {:ok, :percent}
    end

    test "validates between of percents as boolean", %{ctx: ctx} do
      assert Elex.validate("between(15%, 10%, 20%)", ctx) == {:ok, :boolean}
    end
  end

  describe "point functions own percent values" do
    test "min call returns the smaller percent" do
      assert {:ok, %Elex.Percent{value: value}} =
               Elex.Functions.Min.call([percent("30"), percent("10"), percent("20")])

      assert Decimal.equal?(value, Decimal.new("10"))
    end

    test "max call returns the larger percent" do
      assert {:ok, %Elex.Percent{value: value}} =
               Elex.Functions.Max.call([percent("30"), percent("10")])

      assert Decimal.equal?(value, Decimal.new("30"))
    end

    test "clamp call returns a percent" do
      assert {:ok, %Elex.Percent{value: value}} =
               Elex.Functions.Clamp.call([percent("150"), percent("0"), percent("100")])

      assert Decimal.equal?(value, Decimal.new("100"))
    end

    test "between call returns a boolean for percents" do
      assert Elex.Functions.Between.call([percent("15"), percent("10"), percent("20")]) ==
               {:ok, true}
    end

    test "clamp call rejects an inverted percent range" do
      assert Elex.Functions.Clamp.call([percent("1"), percent("20"), percent("10")]) ==
               {:error, "clamp min must be less than or equal to max"}
    end

    test "between call rejects an inverted percent range" do
      assert Elex.Functions.Between.call([percent("1"), percent("20"), percent("10")]) ==
               {:error, "between low must be less than or equal to high"}
    end
  end

  describe "percent min and between errors" do
    test "rejects mixing a percent with a number in min", %{ctx: ctx} do
      assert_type_error("min(10%, 1)", "cannot mix percent and number", ctx)
    end

    test "rejects mixing a percent with a number in between", %{ctx: ctx} do
      assert_type_error("between(15%, 10%, 1)", "cannot mix percent and number", ctx)
    end

    test "clamp rejects an inverted percent range", %{ctx: ctx} do
      assert Elex.evaluate("clamp(1%, 20%, 10%)", ctx) ==
               {:error, "clamp min must be less than or equal to max"}
    end

    test "between rejects an inverted percent range", %{ctx: ctx} do
      assert Elex.evaluate("between(1%, 20%, 10%)", ctx) ==
               {:error, "between low must be less than or equal to high"}
    end
  end

  defp percent(value), do: %Elex.Percent{value: Decimal.new(value)}

  defp assert_percent(expression, expected, ctx) do
    assert {:ok, %Elex.Percent{value: value}} = Elex.evaluate(expression, ctx)
    assert Decimal.equal?(value, Decimal.new(expected))
  end

  defp assert_type_error(expression, message, ctx) do
    assert Elex.validate(expression, ctx) == {:error, message}
    assert Elex.evaluate(expression, ctx) == {:error, message}
  end
end
