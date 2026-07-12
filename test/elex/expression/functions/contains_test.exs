defmodule Elex.Functions.ContainsTest do
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

  describe "contains/2 function" do
    test "returns true when needle is found" do
      assert parse_and_evaluate(~s[contains("hello", "ell")]) == true
    end

    test "returns false when needle is not found" do
      assert parse_and_evaluate(~s[contains("hello", "xyz")]) == false
    end

    test "evaluates with variables" do
      vars = %{
        "haystack" => %Variable{value: "hello", type: :string},
        "needle" => %Variable{value: "ell", type: :string}
      }

      assert parse_and_evaluate("contains(haystack, needle)", vars) == true
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate(~s[contains(concat("he", "llo"), "ell")]) == true
    end

    test "non-string argument" do
      assert {:error, "contains function expects string arguments, got decimal"} =
               parse(~s[contains(1, "ell")])
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} =
               parse(~s[contains(missing, "ell")])
    end

    test "wrong number of arguments" do
      assert {:error, "contains function expects 2 arguments"} = parse(~s[contains("hello")])
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Contains.documentation()
      assert is_map(doc)
      assert doc.signature == "contains(haystack, needle)"
      assert is_binary(doc.description)
    end
  end
end
