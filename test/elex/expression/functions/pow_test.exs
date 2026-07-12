defmodule Elex.Functions.PowTest do
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

  describe "pow/2 function" do
    test "evaluates with literals" do
      assert parse_and_evaluate("pow(2, 3)") == Decimal.new("8")
      assert parse_and_evaluate("pow(4, 0.5)") == Decimal.new("2")
    end

    test "evaluates with variables" do
      vars = %{
        "base" => %Variable{value: Decimal.new("2"), type: :decimal},
        "exp" => %Variable{value: Decimal.new("3"), type: :decimal}
      }

      assert parse_and_evaluate("pow(base, exp)", vars) == Decimal.new("8")
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate("pow(1 + 1, 1 + 2)") == Decimal.new("8")
    end

    test "first argument non-decimal" do
      assert {:error, "pow function expects number arguments, got string"} =
               parse("pow(\"foo\", 2)")
    end

    test "second argument non-decimal" do
      assert {:error, "pow function expects number arguments, got string"} =
               parse("pow(3, \"foo\")")
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("pow(missing, 2)")
    end

    test "wrong number of arguments" do
      assert {:error, "pow function expects 2 arguments"} = parse("pow(5)")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Pow.documentation()
      assert is_map(doc)
      assert doc.signature == "pow(base, exponent)"
      assert is_binary(doc.description)
    end
  end
end
