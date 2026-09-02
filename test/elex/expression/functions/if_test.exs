defmodule Elex.Functions.IfTest do
  use ExUnit.Case, async: true

  alias Elex.{Evaluator, Parser, Validator, Variable}

  defp eval(expression, ctx \\ Elex.new_context()) do
    case Parser.parse(expression, ctx) do
      {:ok, ast, _} ->
        {:ok, Evaluator.evaluate!(ast, ctx)}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e in RuntimeError -> {:error, %{reason: e.message, type: :runtime}}
  end

  defp validate(expression, ctx \\ Elex.new_context()) do
    case Parser.parse(expression, ctx, validate: false) do
      {:ok, ast, _} ->
        case Validator.validate(ast, ctx) do
          {:ok, type} -> {:ok, %{type: type}}
          {:error, reason} -> {:error, %{reason: reason, type: :validation}}
        end

      {:error, reason} ->
        {:error, %{reason: reason, type: :parse}}
    end
  end

  describe "if/3 function" do
    test "evaluates true branch when condition is true" do
      assert {:ok, Decimal.new(10)} == eval("if(true, 10, 20)")
      assert {:ok, "yes"} == eval(~s[if(1 == 1, "yes", "no")])
    end

    test "evaluates false branch when condition is false" do
      assert {:ok, Decimal.new(20)} == eval("if(false, 10, 20)")
      assert {:ok, "no"} == eval(~s[if(1 > 2, "yes", "no")])
    end

    test "validation fails if condition is not boolean" do
      assert {:error, %{reason: "if condition must be a boolean, got number", type: :validation}} =
               validate("if(1, 10, 20)")

      assert {:error, %{reason: "if condition must be a boolean, got text", type: :validation}} =
               validate("if(\"text\", 10, 20)")
    end

    test "validation fails if branches have different types" do
      assert {:error,
              %{
                reason: "if branches must have the same type, got number and text",
                type: :validation
              }} =
               validate("if(true, 10, \"text\")")

      assert {:error,
              %{
                reason: "if branches must have the same type, got yes/no and number",
                type: :validation
              }} =
               validate("if(false, true, 10)")
    end

    test "validation succeeds if branches have the same type" do
      assert {:ok, %{type: :decimal}} == validate("if(true, 10, 20)")
      assert {:ok, %{type: :string}} == validate(~s[if(false, "a", "b")])
      assert {:ok, %{type: :boolean}} == validate("if(true, true, false)")
    end

    test "propagates nested validation errors" do
      assert {:error, %{reason: "variable 'missing' does not exist", type: :validation}} =
               validate("if(missing, 1, 2)")
    end

    test "nested if functions" do
      assert {:ok, Decimal.new(30)} == eval("if(1 < 2, if(true, 30, 40), 50)")
      assert {:ok, Decimal.new(50)} == eval("if(1 > 2, if(true, 30, 40), 50)")
    end

    test "does not evaluate the false branch when the condition is true" do
      assert {:ok, Decimal.new(1)} == eval("if(true, 1, 1 / 0)")
    end

    test "does not evaluate the true branch when the condition is false" do
      assert {:ok, Decimal.new(2)} == eval("if(false, 1 / 0, 2)")
    end

    test "validation with variables" do
      context =
        Elex.new_context(%{
          "cond" => %Variable{value: true, type: :boolean},
          "val1" => %Variable{value: Decimal.new(10), type: :decimal},
          "val2" => %Variable{value: Decimal.new(20), type: :decimal},
          "str" => %Variable{value: "text", type: :string}
        })

      assert {:ok, %{type: :decimal}} == validate("if(cond, val1, val2)", context)

      assert {:error,
              %{
                reason: "if branches must have the same type, got number and text",
                type: :validation
              }} =
               validate("if(cond, val1, str)", context)

      assert {:error, %{reason: "if condition must be a boolean, got number", type: :validation}} =
               validate("if(val1, val1, val2)", context)
    end

    test "evaluation with variables" do
      context =
        Elex.new_context(%{
          "cond" => %Variable{value: false, type: :boolean},
          "val1" => %Variable{value: Decimal.new(10), type: :decimal},
          "val2" => %Variable{value: Decimal.new(20), type: :decimal}
        })

      assert {:ok, Decimal.new(20)} == eval("if(cond, val1, val2)", context)
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.If.documentation()
      assert is_map(doc)
      assert doc.signature == "if(condition, value1, value2)"
      assert is_binary(doc.description)
    end
  end
end
