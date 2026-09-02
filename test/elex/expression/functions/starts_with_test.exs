defmodule Elex.Functions.StartsWithTest do
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

  describe "starts_with/2 function" do
    test "returns true when text starts with prefix" do
      assert parse_and_evaluate(~s[starts_with("hello", "he")]) == true
    end

    test "returns false when text does not start with prefix" do
      assert parse_and_evaluate(~s[starts_with("hello", "lo")]) == false
    end

    test "evaluates with variables" do
      vars = %{
        "text" => %Variable{value: "hello", type: :string},
        "prefix" => %Variable{value: "he", type: :string}
      }

      assert parse_and_evaluate("starts_with(text, prefix)", vars) == true
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate(~s[starts_with(concat("he", "llo"), "he")]) == true
    end

    test "non-string argument" do
      assert {:error, "starts_with function expects string arguments, got decimal"} =
               parse(~s[starts_with(1, "he")])
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} =
               parse(~s[starts_with(missing, "he")])
    end

    test "wrong number of arguments" do
      assert {:error, "starts_with function expects 2 arguments"} =
               parse(~s[starts_with("hello")])
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.StartsWith.documentation()
      assert is_map(doc)
      assert doc.signature == "starts_with(text, prefix)"
      assert is_binary(doc.description)
    end
  end
end
