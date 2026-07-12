defmodule Elex.Functions.BetweenTest do
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
        Evaluator.evaluate(ast, ctx)

      {:error, reason} ->
        flunk("Parsing and evaluation failed unexpectedly: #{reason}")
    end
  end

  describe "between/3 function" do
    test "returns true when value is within inclusive bounds" do
      assert parse_and_evaluate("between(5, 0, 10)") == true
    end

    test "returns false when value is below bounds" do
      assert parse_and_evaluate("between(-1, 0, 10)") == false
    end

    test "returns true when value equals upper bound" do
      assert parse_and_evaluate("between(10, 0, 10)") == true
    end

    test "returns true when value equals lower bound" do
      assert parse_and_evaluate("between(0, 0, 10)") == true
    end

    test "returns false when value is above bounds" do
      assert parse_and_evaluate("between(11, 0, 10)") == false
    end

    test "evaluates with variables" do
      vars = %{
        "val" => %Variable{value: Decimal.new("5"), type: :decimal},
        "low" => %Variable{value: Decimal.new("0"), type: :decimal},
        "high" => %Variable{value: Decimal.new("10"), type: :decimal}
      }

      assert parse_and_evaluate("between(val, low, high)", vars) == true
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate("between(1 + 4, 0, 1 + 9)") == true
    end

    test "non-decimal argument" do
      assert {:error, "between function expects number arguments, got string"} =
               parse("between(\"foo\", 0, 10)")
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("between(missing, 0, 10)")
    end

    test "wrong number of arguments" do
      assert {:error, "between function expects 3 arguments"} = parse("between(5, 0)")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Between.documentation()
      assert is_map(doc)
      assert doc.signature == "between(x, low, high)"
      assert is_binary(doc.description)
    end
  end
end
