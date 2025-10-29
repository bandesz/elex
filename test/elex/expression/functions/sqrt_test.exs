defmodule Elex.Functions.SqrtTest do
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

  describe "sqrt/1 function" do
    test "evaluates with literals" do
      assert parse_and_evaluate("sqrt(4)") == Decimal.new("2")
      assert parse_and_evaluate("sqrt(1.44)") == Decimal.new("1.2")
    end

    test "evaluates with variables" do
      vars = %{
        "a" => %Variable{value: Decimal.new("9"), type: :decimal}
      }

      assert parse_and_evaluate("sqrt(a)", vars) == Decimal.new("3")
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate("sqrt(4 + 5)") == Decimal.new("3")
    end

    test "argument non-decimal" do
      assert {:error, "sqrt function expects a number argument, got string"} =
               parse("sqrt(\"foo\")")
    end

    test "wrong number of arguments" do
      assert {:error, "sqrt function expects 1 argument"} = parse("sqrt()")
    end
  end
end
