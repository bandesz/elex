defmodule Elex.Functions.ModTest do
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

  describe "mod/2 function" do
    test "evaluates with literals" do
      assert parse_and_evaluate("mod(10, 3)") == Decimal.new("1")
      assert parse_and_evaluate("mod(-3, 2)") == Decimal.new("1")
      assert parse_and_evaluate("mod(-3, -2)") == Decimal.new("-1")
      assert parse_and_evaluate("mod(3, -2)") == Decimal.new("-1")
      assert parse_and_evaluate("mod(3.1, 2.1)") == Decimal.new("1.0")
    end

    test "differs from rem for negative dividends" do
      assert parse_and_evaluate("mod(-3, 2)") == Decimal.new("1")
      assert parse_and_evaluate("rem(-3, 2)") == Decimal.new("-1")
    end

    test "evaluates with variables" do
      vars = %{
        "val1" => %Variable{value: Decimal.new("10"), type: :decimal},
        "val2" => %Variable{value: Decimal.new("3"), type: :decimal}
      }

      assert parse_and_evaluate("mod(val1, val2)", vars) == Decimal.new("1")
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate("mod(1 + 9, 1 + 2)") == Decimal.new("1")
    end

    test "first argument non-decimal" do
      assert {:error, "mod function expects number arguments, got string"} =
               parse("mod(\"foo\", 2)")
    end

    test "second argument non-decimal" do
      assert {:error, "mod function expects number arguments, got string"} =
               parse("mod(3, \"foo\")")
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("mod(missing, 2)")
    end

    test "returns evaluation error when dividing by zero" do
      ctx = Elex.new_context()

      assert {:error, "Evaluation error: " <> _} =
               Elex.evaluate("mod(10, 0)", ctx)
    end

    test "wrong number of arguments" do
      assert {:error, "mod function expects 2 arguments"} = parse("mod(5)")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Mod.documentation()
      assert is_map(doc)
      assert doc.signature == "mod(a, b)"
      assert is_binary(doc.description)
    end
  end
end
