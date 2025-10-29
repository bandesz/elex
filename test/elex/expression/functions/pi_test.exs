defmodule Elex.Functions.PiTest do
  use ExUnit.Case, async: true

  alias Elex.{Parser, Evaluator}
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

  describe "pi/0 function" do
    test "evaluates" do
      assert Decimal.compare(parse_and_evaluate("pi()"), Decimal.new("3.141592653589793")) == :eq
    end

    test "wrong number of arguments" do
      assert {:error, "pi function expects no arguments"} = parse("pi(1)")
    end
  end
end
