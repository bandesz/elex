defmodule Elex.ParserTest do
  use ExUnit.Case, async: true

  alias Elex.{Parser, Variable}

  describe "parse/3 with validate option" do
    test "parses and validates by default" do
      ctx = Elex.new_context(%{"x" => %Variable{value: Decimal.new(1), type: :decimal}})
      assert {:ok, {:var, "x"}, :decimal} = Parser.parse("x", ctx)
    end

    test "parses and validates when validate: true" do
      ctx = Elex.new_context(%{"x" => %Variable{value: Decimal.new(1), type: :decimal}})
      assert {:ok, {:var, "x"}, :decimal} = Parser.parse("x", ctx, validate: true)
    end

    test "parses without validation when validate: false" do
      ctx = Elex.new_context(%{"x" => %Variable{value: Decimal.new(1), type: :decimal}})
      assert {:ok, {:var, "x"}, nil} = Parser.parse("x", ctx, validate: false)
    end

    test "returns validation error when validate: true and invalid expression" do
      ctx = Elex.new_context()
      assert {:error, "variable 'unknown' does not exist"} = Parser.parse("unknown", ctx)
    end

    test "does not return validation error when validate: false and invalid expression" do
      ctx = Elex.new_context()
      assert {:ok, {:var, "unknown"}, nil} = Parser.parse("unknown", ctx, validate: false)
    end
  end
end
