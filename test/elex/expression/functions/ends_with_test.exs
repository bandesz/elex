defmodule Elex.Functions.EndsWithTest do
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

  describe "ends_with/2 function" do
    test "returns true when text ends with suffix" do
      assert parse_and_evaluate(~s[ends_with("hello", "lo")]) == true
    end

    test "returns false when text does not end with suffix" do
      assert parse_and_evaluate(~s[ends_with("hello", "he")]) == false
    end

    test "evaluates with variables" do
      vars = %{
        "text" => %Variable{value: "hello", type: :string},
        "suffix" => %Variable{value: "lo", type: :string}
      }

      assert parse_and_evaluate("ends_with(text, suffix)", vars) == true
    end

    test "evaluates nested expressions" do
      assert parse_and_evaluate(~s[ends_with(concat("hel", "lo"), "lo")]) == true
    end

    test "non-string argument" do
      assert {:error, "ends_with function expects string arguments, got decimal"} =
               parse(~s[ends_with(1, "lo")])
    end

    test "propagates nested validation errors" do
      assert {:error, "variable 'missing' does not exist"} =
               parse(~s[ends_with(missing, "lo")])
    end

    test "wrong number of arguments" do
      assert {:error, "ends_with function expects 2 arguments"} = parse(~s[ends_with("hello")])
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.EndsWith.documentation()
      assert is_map(doc)
      assert doc.signature == "ends_with(text, suffix)"
      assert is_binary(doc.description)
    end
  end
end
