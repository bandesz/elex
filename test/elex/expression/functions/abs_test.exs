defmodule Elex.Functions.AbsTest do
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

  describe "abs/1 function" do
    test "evaluates with literals" do
      assert parse_and_evaluate("abs(-5)") == Decimal.new("5")
      assert parse_and_evaluate("abs(3.2)") == Decimal.new("3.2")
    end

    test "evaluates with variables" do
      vars = %{
        "a" => %Variable{value: Decimal.new("-9"), type: :decimal}
      }

      assert parse_and_evaluate("abs(a)", vars) == Decimal.new("9")
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate("abs(-4 + 1)") == Decimal.new("3")
    end

    test "argument non-decimal" do
      assert {:error, "abs function expects a number argument, got string"} =
               parse("abs(\"foo\")")
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("abs(missing)")
    end

    test "wrong number of arguments" do
      assert {:error, "abs function expects 1 argument"} = parse("abs()")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Abs.documentation()
      assert is_map(doc)
      assert doc.signature == "abs(x)"
      assert is_binary(doc.description)
    end
  end
end
