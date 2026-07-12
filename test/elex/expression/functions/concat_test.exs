defmodule Elex.Functions.ConcatTest do
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

  describe "concat/2 function" do
    test "concatenates two strings" do
      assert parse_and_evaluate(~s[concat("a", "b")]) == "ab"
    end

    test "evaluates with variables" do
      vars = %{
        "a" => %Variable{value: "hello", type: :string},
        "b" => %Variable{value: " world", type: :string}
      }

      assert parse_and_evaluate("concat(a, b)", vars) == "hello world"
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate(~s[concat("a", concat("b", "c"))]) == "abc"
    end

    test "non-string argument" do
      assert {:error, "concat function expects string arguments, got decimal"} =
               parse(~s[concat(1, "b")])
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} = parse("concat(missing, \"b\")")
    end

    test "wrong number of arguments" do
      assert {:error, "concat function expects 2 arguments"} = parse("concat(\"a\")")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Concat.documentation()
      assert is_map(doc)
      assert doc.signature == "concat(a, b)"
      assert is_binary(doc.description)
    end
  end
end
