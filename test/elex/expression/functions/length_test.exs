defmodule Elex.Functions.LengthTest do
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

  describe "length/1 function" do
    test "returns string length as decimal" do
      assert parse_and_evaluate(~s[length("hello")]) == Decimal.new("5")
    end

    test "evaluates with variables" do
      vars = %{
        "s" => %Variable{value: "hello", type: :string}
      }

      assert parse_and_evaluate("length(s)", vars) == Decimal.new("5")
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate(~s[length(concat("he", "llo"))]) == Decimal.new("5")
    end

    test "non-string argument" do
      assert {:error, "length function expects a string argument, got decimal"} =
               parse("length(42)")
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("length(missing)")
    end

    test "wrong number of arguments" do
      assert {:error, "length function expects 1 argument"} = parse("length()")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Length.documentation()
      assert is_map(doc)
      assert doc.signature == "length(s)"
      assert is_binary(doc.description)
    end
  end
end
