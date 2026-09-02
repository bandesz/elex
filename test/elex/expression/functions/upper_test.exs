defmodule Elex.Functions.UpperTest do
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

  describe "upper/1 function" do
    test "converts string to uppercase" do
      assert parse_and_evaluate(~s[upper("AbC")]) == "ABC"
    end

    test "evaluates with variables" do
      vars = %{
        "s" => %Variable{value: "AbC", type: :string}
      }

      assert parse_and_evaluate("upper(s)", vars) == "ABC"
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate(~s[upper(concat("a", "bC"))]) == "ABC"
    end

    test "non-string argument" do
      assert {:error, "upper function expects a string argument, got decimal"} =
               parse("upper(42)")
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("upper(missing)")
    end

    test "wrong number of arguments" do
      assert {:error, "upper function expects 1 argument"} = parse("upper()")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Upper.documentation()
      assert is_map(doc)
      assert doc.signature == "upper(s)"
      assert is_binary(doc.description)
    end
  end
end
