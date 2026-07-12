defmodule Elex.Functions.TrimTest do
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

  describe "trim/1 function" do
    test "removes leading and trailing whitespace" do
      assert parse_and_evaluate(~s[trim("  hi  ")]) == "hi"
    end

    test "evaluates with variables" do
      vars = %{
        "s" => %Variable{value: "  hi  ", type: :string}
      }

      assert parse_and_evaluate("trim(s)", vars) == "hi"
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate(~s[trim(concat("  hi", "  "))]) == "hi"
    end

    test "non-string argument" do
      assert {:error, "trim function expects a string argument, got decimal"} =
               parse("trim(42)")
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("trim(missing)")
    end

    test "wrong number of arguments" do
      assert {:error, "trim function expects 1 argument"} = parse("trim()")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Trim.documentation()
      assert is_map(doc)
      assert doc.signature == "trim(s)"
      assert is_binary(doc.description)
    end
  end
end
