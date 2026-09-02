defmodule Elex.Functions.ClampTest do
  use ExUnit.Case, async: true

  alias Elex.{Parser, Evaluator, Variable}
  alias Elex

  defp parse(expression, variables \\ %{}) do
    ctx = Elex.new_context(variables)
    Parser.parse(expression, ctx)
  end

  defp parse_and_evaluate(expression, variables \\ %{}) do
    ctx = Elex.new_context(variables)

    case Parser.parse(expression, ctx) do
      {:ok, ast, _type} ->
        Evaluator.evaluate!(ast, ctx)

      {:error, reason} ->
        flunk("Parsing and evaluation failed unexpectedly: #{reason}")
    end
  end

  describe "clamp/3 function" do
    test "returns value when within bounds" do
      assert parse_and_evaluate("clamp(5, 0, 10)") == Decimal.new("5")
    end

    test "returns min when value is below bounds" do
      assert parse_and_evaluate("clamp(-1, 0, 10)") == Decimal.new("0")
    end

    test "returns max when value is above bounds" do
      assert parse_and_evaluate("clamp(15, 0, 10)") == Decimal.new("10")
    end

    test "evaluates with variables" do
      vars = %{
        "val" => %Variable{value: Decimal.new("15"), type: :decimal},
        "low" => %Variable{value: Decimal.new("0"), type: :decimal},
        "high" => %Variable{value: Decimal.new("10"), type: :decimal}
      }

      assert parse_and_evaluate("clamp(val, low, high)", vars) == Decimal.new("10")
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate("clamp(1 + 4, 0, 1 + 9)") == Decimal.new("5")
    end

    test "non-decimal argument" do
      assert {:error, "clamp function expects number arguments, got string"} =
               parse("clamp(\"foo\", 0, 10)")
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("clamp(missing, 0, 10)")
    end

    test "returns evaluation error when min is greater than max" do
      ctx = Elex.new_context()

      assert {:error, "clamp min must be less than or equal to max"} =
               Elex.evaluate("clamp(5, 10, 0)", ctx)
    end

    test "wrong number of arguments" do
      assert {:error, "clamp function expects 3 arguments"} = parse("clamp(5, 0)")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Clamp.documentation()
      assert is_map(doc)
      assert doc.signature == "clamp(x, min, max)"
      assert is_binary(doc.description)
    end
  end
end
