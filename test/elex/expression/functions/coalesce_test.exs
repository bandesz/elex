defmodule Elex.Functions.CoalesceTest do
  use ExUnit.Case, async: true

  alias Elex.{Evaluator, Parser, Validator}

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

  defp parse(expression, ctx \\ Elex.new_context()) do
    Parser.parse(expression, ctx)
  end

  describe "coalesce function" do
    test "returns first non-nil value" do
      assert {:ok, Decimal.new(5)} == eval("coalesce(null, 5)")
      assert {:ok, Decimal.new(10)} == eval("coalesce(null, null, 10)")
      assert {:ok, Decimal.new(3)} == eval("coalesce(3, 5)")
    end

    test "returns nil when all arguments are null" do
      assert {:ok, nil} == eval("coalesce(null, null)")
    end

    test "short-circuits and does not evaluate later arguments" do
      assert {:ok, Decimal.new(1)} == eval("coalesce(null, 1, 1 / 0)")
      assert {:ok, Decimal.new(1)} == eval("coalesce(1, 1 / 0)")
    end

    test "requires at least two arguments" do
      assert {:error, "coalesce function expects 2 arguments"} = parse("coalesce(5)")
    end

    test "validation fails when arguments have different types" do
      assert {:error,
              %{
                reason: "coalesce arguments must have the same type, got number and text",
                type: :validation
              }} =
               validate("coalesce(3, \"x\")")

      assert {:error,
              %{
                reason: "coalesce arguments must have the same type, got number and text",
                type: :validation
              }} =
               validate("coalesce(null, 3, \"x\")")
    end

    test "validation succeeds when arguments share the same type" do
      assert {:ok, %{type: :decimal}} == validate("coalesce(null, 5)")
      assert {:ok, %{type: :decimal}} == validate("coalesce(null, null, 10)")
      assert {:ok, %{type: :decimal}} == validate("coalesce(3, 5)")
      assert {:ok, %{type: nil}} == validate("coalesce(null, null)")
      assert {:ok, %{type: :string}} == validate(~s[coalesce(null, "x")])
    end

    test "propagates nested validation errors" do
      assert {:error, %{reason: "variable 'missing' does not exist", type: :validation}} =
               validate("coalesce(missing, 1)")
    end
  end

  describe "documentation/0" do
    test "returns documentation map" do
      doc = Elex.Functions.Coalesce.documentation()
      assert is_map(doc)
      assert doc.signature == "coalesce(a, b, ...)"
      assert is_binary(doc.description)
    end
  end
end
