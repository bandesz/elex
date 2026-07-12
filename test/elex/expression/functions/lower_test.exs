defmodule Elex.Functions.LowerTest do
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

  describe "lower/1 function" do
    test "converts string to lowercase" do
      assert parse_and_evaluate(~s[lower("AbC")]) == "abc"
    end

    test "evaluates with variables" do
      vars = %{
        "s" => %Variable{value: "AbC", type: :string}
      }

      assert parse_and_evaluate("lower(s)", vars) == "abc"
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate(~s[lower(concat("A", "bC"))]) == "abc"
    end

    test "non-string argument" do
      assert {:error, "lower function expects a string argument, got decimal"} =
               parse("lower(42)")
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("lower(missing)")
    end

    test "wrong number of arguments" do
      assert {:error, "lower function expects 1 argument"} = parse("lower()")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Lower.documentation()
      assert is_map(doc)
      assert doc.signature == "lower(s)"
      assert is_binary(doc.description)
    end
  end
end
