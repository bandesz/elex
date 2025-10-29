defmodule Elex.Functions.MaxTest do
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

  describe "max/2 function" do
    test "evaluates with literals" do
      assert parse_and_evaluate("max(3, 2)") == Decimal.new("3")
      assert parse_and_evaluate("max(-3, -2)") == Decimal.new("-2")
      assert parse_and_evaluate("max(3.1, 2.1)") == Decimal.new("3.1")
    end

    test "evaluates with variables" do
      vars = %{
        "val1" => %Variable{value: Decimal.new("3"), type: :decimal},
        "val2" => %Variable{value: Decimal.new("2"), type: :decimal}
      }

      assert parse_and_evaluate("max(val1, val2)", vars) == Decimal.new("3")
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate("max(1 + 2, 1 + 1)") == Decimal.new("3")
    end

    test "first argument non-decimal" do
      assert {:error, "max function expects number arguments, got string"} =
               parse("max(\"foo\", 2)")
    end

    test "second argument non-decimal" do
      assert {:error, "max function expects number arguments, got string"} =
               parse("max(3, \"foo\")")
    end

    test "wrong number of arguments" do
      assert {:error, "max function expects 2 arguments"} = parse("max(3)")
    end
  end
end
