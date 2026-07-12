defmodule Elex.Functions.CeilTest do
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

  describe "ceil/1 function" do
    test "evaluates with literals" do
      assert parse_and_evaluate("ceil(1.2)") == Decimal.new("2")
      assert parse_and_evaluate("ceil(1.7)") == Decimal.new("2")
      assert parse_and_evaluate("ceil(2.0)") == Decimal.new("2")
      assert parse_and_evaluate("ceil(-1.2)") == Decimal.new("-1")
      assert parse_and_evaluate("ceil(-1.7)") == Decimal.new("-1")
      assert parse_and_evaluate("ceil(-2.0)") == Decimal.new("-2")
      assert parse_and_evaluate("ceil(0.0)") == Decimal.new("0")
      assert parse_and_evaluate("ceil(12345.6789)") == Decimal.new("12346")
    end

    test "evaluates with variables" do
      vars = %{
        "val1" => %Variable{value: Decimal.new("9.87"), type: :decimal},
        "val2" => %Variable{value: Decimal.new("-3.14"), type: :decimal},
        "val3" => %Variable{value: Decimal.new("5"), type: :decimal}
      }

      assert parse_and_evaluate("ceil(val1)", vars) == Decimal.new("10")
      assert parse_and_evaluate("ceil(val2)", vars) == Decimal.new("-3")
      assert parse_and_evaluate("ceil(val3)", vars) == Decimal.new("5")
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate("ceil(10.5 + 5.2)") == Decimal.new("16")
      assert parse_and_evaluate("ceil(1.7) + 5.2") == Decimal.new("7.2")

      vars = %{
        "price" => %Variable{value: Decimal.new("19.95"), type: :decimal},
        "qty" => %Variable{value: Decimal.new("2"), type: :decimal}
      }

      assert parse_and_evaluate("ceil(price * qty)", vars) == Decimal.new("40")
    end

    test "argument non-decimal" do
      assert {:error, "ceil function expects a number argument, got string"} =
               parse("ceil(\"foo\")")
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("ceil(missing)")
    end

    test "wrong number of arguments" do
      assert {:error, "ceil function expects 1 argument"} = parse("ceil()")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Ceil.documentation()
      assert is_map(doc)
      assert doc.signature == "ceil(x)"
      assert is_binary(doc.description)
    end
  end
end
