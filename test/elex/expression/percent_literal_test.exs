defmodule Elex.PercentLiteralTest do
  use ExUnit.Case, async: true

  alias Elex.{Context, Parser}
  alias Elex.Percent
  alias Elex.Units.Catalog

  setup do
    %{ctx: Elex.new_context()}
  end

  describe "evaluate/3 percent literals" do
    test "evaluates a percent literal as percent points", %{ctx: ctx} do
      assert_percent("50%", "50", ctx)
    end

    test "ignores whitespace around the percent suffix", %{ctx: ctx} do
      assert_percent("50 %", "50", ctx)
      assert_percent("50% ", "50", ctx)
    end

    test "normalizes a scientific percent literal", %{ctx: ctx} do
      assert {:ok, percent} = Elex.evaluate("1e2%", ctx)
      assert inspect(percent) == "#Elex.Percent<100%>"
      assert Decimal.equal?(percent.value, Decimal.new("100"))
    end

    test "evaluates a negative percent literal", %{ctx: ctx} do
      assert_percent("-10%", "-10", ctx)
    end

    test "evaluates zero and values outside 0 to 100", %{ctx: ctx} do
      assert_percent("0%", "0", ctx)
      assert_percent("150%", "150", ctx)
      assert_percent("-150%", "-150", ctx)
    end

    test "negates a parenthesized percent literal", %{ctx: ctx} do
      assert_percent("-(50%)", "-50", ctx)
    end
  end

  describe "validate/3 percent literals" do
    test "types a percent literal as :percent", %{ctx: ctx} do
      assert Elex.validate("50%", ctx) == {:ok, :percent}
    end

    test "types a percent literal as :percent when a length catalog is attached" do
      assert Elex.validate("50%", length_context()) == {:ok, :percent}
    end
  end

  describe "Parser.parse/3 percent literals" do
    test "parses a percent literal", %{ctx: ctx} do
      assert Parser.parse("50%", ctx) == {:ok, {:percent, Decimal.new("50")}, :percent}
    end

    test "keeps the minus inside a negative percent literal", %{ctx: ctx} do
      assert Parser.parse("-10%", ctx) == {:ok, {:percent, Decimal.new("-10")}, :percent}
    end

    test "parses unary minus around a parenthesized percent", %{ctx: ctx} do
      assert Parser.parse("-(50%)", ctx) ==
               {:ok, {:-, {:percent, Decimal.new("50")}}, :percent}
    end

    test "returns a nil type when validation is disabled", %{ctx: ctx} do
      assert Parser.parse("50%", ctx, validate: false) ==
               {:ok, {:percent, Decimal.new("50")}, nil}
    end
  end

  describe "extract_variables/2" do
    test "does not treat a percent literal as a name", %{ctx: ctx} do
      assert Elex.extract_variables("100 * rate + 50%", ctx) == {:ok, ["rate"]}
    end
  end

  describe "percent literal parse errors" do
    test "rejects a percent suffix that is not part of a number literal", %{ctx: ctx} do
      assert Elex.evaluate("(10+20)%", ctx) == {:error, "unexpected '%'"}
      assert Elex.evaluate("rate%", ctx) == {:error, "unexpected '%'"}
      assert Elex.evaluate("50%%", ctx) == {:error, "unexpected '%'"}
    end

    test "rejects a unit glued after a percent suffix", %{ctx: ctx} do
      assert Elex.evaluate("50%cm", ctx) == {:error, "unexpected 'cm'"}
    end

    test "rejects a leading dot the same way with or without a percent suffix", %{ctx: ctx} do
      assert {:error, message} = Elex.evaluate(".5", ctx)
      assert Elex.evaluate(".5%", ctx) == {:error, message}
    end
  end

  defp assert_percent(expression, points, ctx) do
    assert {:ok, %Percent{value: value}} = Elex.evaluate(expression, ctx)
    assert Decimal.equal?(value, Decimal.new(points))
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
