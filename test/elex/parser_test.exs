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

    test "returns parse error even when validate: false for a syntactically invalid expression" do
      ctx = Elex.new_context()
      assert {:error, "Parse error at line 1:" <> _} = Parser.parse("1 +", ctx, validate: false)
    end
  end

  describe "parse/3 syntax errors" do
    test "parse error includes the line number" do
      ctx = Elex.new_context()
      assert {:error, message} = Parser.parse("1 +", ctx)
      assert message =~ "Parse error at line 1:"
    end

    test "returns a parse error for an empty string" do
      ctx = Elex.new_context()
      assert {:error, message} = Parser.parse("", ctx)
      assert message =~ "Parse error at line 1:"
    end
  end

  describe "parse/3 boolean aliases" do
    test "parses 'yes' as boolean true" do
      ctx = Elex.new_context()
      assert {:ok, true, :boolean} = Parser.parse("yes", ctx)
    end

    test "parses 'no' as boolean false" do
      ctx = Elex.new_context()
      assert {:ok, false, :boolean} = Parser.parse("no", ctx)
    end
  end
end
