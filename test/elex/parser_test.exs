defmodule Elex.ParserTest do
  use ExUnit.Case, async: true

  alias Elex.{Parser, Variable}

  doctest Elex.Parser, only: [debug: 2]

  describe "debug/1" do
    test "returns the parsed AST and empty rest on success" do
      info = Parser.debug("1 + 2")

      assert %{
               expression: "1 + 2",
               status: :ok,
               reason: nil,
               rest: "",
               consumed: "1 + 2",
               line: 1,
               byte_offset: 5
             } = info

      assert {:+, [_, _]} = info.ast
    end

    test "exposes the raw parser error, rest and consumed portion on failure" do
      info = Parser.debug("1 + 2 )")

      assert info.status == :error
      assert info.ast == nil
      assert is_binary(info.reason)
      assert info.rest == ")"
      assert info.consumed == "1 + 2 "
      assert info.byte_offset == 6
    end

    test "reports the position of the furthest failure" do
      info = Parser.debug("( 1 + 2")

      assert info.status == :error
      assert info.rest == "( 1 + 2"
      assert info.consumed == ""
      assert info.byte_offset == 0
    end

    test "rejects expressions deeper than the default limit before parsing" do
      expression = nest("1", 17)
      info = Parser.debug(expression)

      assert %{
               status: :error,
               reason: "expression is nested too deeply (maximum depth is 16)",
               ast: nil,
               rest: ^expression,
               consumed: "",
               byte_offset: 0,
               line: 1,
               column: 0,
               expression: ^expression
             } = info
    end

    test "honours a custom :max_depth option" do
      assert %{status: :ok} = Parser.debug(nest("1", 3), max_depth: 3)

      info = Parser.debug(nest("1", 4), max_depth: 3)
      assert info.status == :error
      assert info.reason == "expression is nested too deeply (maximum depth is 3)"
    end

    test "rejects any nesting when :max_depth is 0" do
      info = Parser.debug("(1)", max_depth: 0)
      assert info.status == :error
      assert info.reason == "expression is nested too deeply (maximum depth is 0)"
    end

    test "returns an error map for an invalid :max_depth" do
      for bad <- [-1, "16", nil, 1.5] do
        info = Parser.debug("1 + 2", max_depth: bad)

        assert %{
                 status: :error,
                 reason: "invalid max_depth: must be a non-negative integer",
                 ast: nil,
                 consumed: "",
                 byte_offset: 0,
                 expression: "1 + 2"
               } = info
      end
    end
  end

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

      assert {:error, "a value is missing after '+'"} =
               Parser.parse("1 +", ctx, validate: false)
    end
  end

  describe "parse/3 human-readable syntax errors" do
    setup do
      %{ctx: Elex.new_context()}
    end

    defp assert_message(expression, expected, ctx) do
      assert {:error, ^expected} = Parser.parse(expression, ctx, validate: false)
    end

    test "empty and blank input", %{ctx: ctx} do
      assert_message("", "the expression is empty", ctx)
      assert_message("   ", "the expression is empty", ctx)
      assert_message("\t", "the expression is empty", ctx)
    end

    test "missing closing parenthesis", %{ctx: ctx} do
      assert_message("( 1 + 2", "closing parenthesis is missing", ctx)
      assert_message("(", "closing parenthesis is missing", ctx)
      assert_message("( ( 1 )", "closing parenthesis is missing", ctx)
      assert_message("max(1,", "closing parenthesis is missing", ctx)
      assert_message("foo(", "closing parenthesis is missing", ctx)
    end

    test "unexpected closing parenthesis", %{ctx: ctx} do
      assert_message("1 + 2 )", "unexpected closing parenthesis", ctx)
      assert_message(")", "unexpected closing parenthesis", ctx)
      assert_message("a )", "unexpected closing parenthesis", ctx)
    end

    test "empty parentheses", %{ctx: ctx} do
      assert_message("()", "an expression is expected inside the parentheses", ctx)
      assert_message("( )", "an expression is expected inside the parentheses", ctx)
    end

    test "unterminated string literal", %{ctx: ctx} do
      assert_message(~s["unterminated], "closing quote is missing", ctx)
      assert_message(~s[( "unclosed], "closing quote is missing", ctx)
    end

    test "invalid backslash escape inside a string", %{ctx: ctx} do
      # The parser only supports `\\"` as an escape, so these never terminate the
      # string cleanly and should read as a missing closing quote rather than an
      # unexpected backslash/quote token.
      assert_message(~s["a\\\\"], "closing quote is missing", ctx)
      assert_message(~s["a\\], "closing quote is missing", ctx)
    end

    test "parentheses and quotes inside string literals are ignored", %{ctx: ctx} do
      assert {:ok, "has ) paren", nil} = Parser.parse(~s["has ) paren"], ctx, validate: false)
    end

    test "a value is missing after a trailing operator", %{ctx: ctx} do
      assert_message("1 +", "a value is missing after '+'", ctx)
      assert_message("1 *", "a value is missing after '*'", ctx)
      assert_message("1 < ", "a value is missing after '<'", ctx)
      assert_message("1 <= ", "a value is missing after '<='", ctx)
      assert_message("1 == == 2", "a value is missing after '=='", ctx)
      assert_message("1 and", "a value is missing after 'and'", ctx)
      assert_message("1 or", "a value is missing after 'or'", ctx)
      assert_message("1 + + 2", "a value is missing after '+'", ctx)
    end

    test "an expression can not start with an operator", %{ctx: ctx} do
      assert_message("+ 1", "an expression can not start with '+'", ctx)
      assert_message("* 1", "an expression can not start with '*'", ctx)
    end

    test "unexpected token or character", %{ctx: ctx} do
      assert_message("1 2", "unexpected '2'", ctx)
      assert_message("1 & 2", "unexpected '&'", ctx)
      assert_message("@", "unexpected '@'", ctx)
      assert_message(~s["a" b], "unexpected 'b'", ctx)
      assert_message("3.", "unexpected '.'", ctx)
    end

    test "missing comma between function arguments", %{ctx: ctx} do
      assert_message("max(1 2)", "arguments must be separated by commas", ctx)
      assert_message("max(1 2 3)", "arguments must be separated by commas", ctx)
      assert_message("max(1, 2 3)", "arguments must be separated by commas", ctx)
      assert_message("foo(a b)", "arguments must be separated by commas", ctx)
      assert_message(~s[max("a" "b")], "arguments must be separated by commas", ctx)
      assert_message("max(1 (2))", "arguments must be separated by commas", ctx)
      assert_message("max((1) (2))", "arguments must be separated by commas", ctx)
    end

    test "malformed function arguments other than a missing comma", %{ctx: ctx} do
      # A non-value token inside the argument list is reported as-is rather than
      # being misattributed to a missing comma.
      assert_message("max(1 & 2)", "unexpected '&'", ctx)
      assert_message("max(1 + )", "a value is missing after '+'", ctx)
      assert_message("max(1,)", "unexpected ','", ctx)
      assert_message("max(,)", "unexpected ','", ctx)
      assert_message("max(1,,2)", "unexpected ','", ctx)
    end

    test "the missing-comma hint is scoped to function calls, not grouping", %{ctx: ctx} do
      # Two values inside a plain grouping are not a function-argument problem:
      # the offending token is reported literally rather than as a missing comma.
      assert_message("(1 2)", "unexpected '2'", ctx)
      assert_message("1 2", "unexpected '2'", ctx)
    end

    test "reports the deepest error inside nested groups and calls", %{ctx: ctx} do
      # Regression coverage for errors that NimbleParsec would otherwise collapse
      # back to the enclosing '(' or ','.
      assert_message("max(1, max(2 3))", "arguments must be separated by commas", ctx)
      assert_message("(max(1 2))", "arguments must be separated by commas", ctx)
      assert_message("((max(1 2)))", "arguments must be separated by commas", ctx)
      assert_message("max(1, 2, foo(3 4))", "arguments must be separated by commas", ctx)
      assert_message("max(min(1 2), 3)", "arguments must be separated by commas", ctx)
      assert_message("((1 2))", "unexpected '2'", ctx)
    end

    test "a stray group after a completed value is reported as an unexpected '('", %{ctx: ctx} do
      # Here the '(' itself is the problem (a missing operator), so we should not
      # descend into the group and report its interior.
      assert_message("1 (2 3)", "unexpected '('", ctx)
      assert_message("max(1)(2)", "unexpected '('", ctx)
    end

    test "a group led by a reserved operator is not a function argument list", %{ctx: ctx} do
      assert_message("not (a b)", "unexpected 'b'", ctx)
      assert_message("not (2 3)", "unexpected '3'", ctx)
    end
  end

  describe "parse/3 nesting depth guard" do
    setup do
      %{ctx: Elex.new_context()}
    end

    defp nest(inner, depth),
      do: String.duplicate("(", depth) <> inner <> String.duplicate(")", depth)

    test "parses expressions at the default depth limit", %{ctx: ctx} do
      assert {:ok, _, nil} = Parser.parse(nest("1", 16), ctx, validate: false)
    end

    test "rejects expressions deeper than the default limit before parsing", %{ctx: ctx} do
      assert {:error, "expression is nested too deeply (maximum depth is 16)"} =
               Parser.parse(nest("1", 17), ctx, validate: false)
    end

    test "rejects deep input quickly instead of parsing it", %{ctx: ctx} do
      # A depth that would take seconds to parse must be rejected near-instantly
      # by the linear pre-scan rather than reaching the exponential parser.
      {microseconds, result} =
        :timer.tc(fn -> Parser.parse(nest("1", 40), ctx, validate: false) end)

      assert {:error, "expression is nested too deeply (maximum depth is 16)"} = result
      assert microseconds < 100_000
    end

    test "honours a custom :max_depth option", %{ctx: ctx} do
      assert {:ok, _, nil} = Parser.parse(nest("1", 3), ctx, validate: false, max_depth: 3)

      assert {:error, "expression is nested too deeply (maximum depth is 3)"} =
               Parser.parse(nest("1", 4), ctx, validate: false, max_depth: 3)
    end

    test "counts function-call parentheses toward the depth", %{ctx: ctx} do
      assert {:error, "expression is nested too deeply (maximum depth is 2)"} =
               Parser.parse("max(min(sqrt(1)))", ctx, validate: false, max_depth: 2)
    end

    test "ignores parentheses inside string literals", %{ctx: ctx} do
      assert {:ok, "((((()))))", nil} =
               Parser.parse(~s["((((()))))"], ctx, validate: false, max_depth: 1)
    end

    test "rejects any nesting when max_depth is 0", %{ctx: ctx} do
      assert {:ok, _, nil} = Parser.parse("1", ctx, validate: false, max_depth: 0)

      assert {:error, "expression is nested too deeply (maximum depth is 0)"} =
               Parser.parse("(1)", ctx, validate: false, max_depth: 0)
    end

    test "treats sibling groups by their own depth, not their sum", %{ctx: ctx} do
      # Two groups at the same level each reach depth 1, so `max_depth: 1`
      # accepts them: depth is the maximum nesting, not a running total.
      assert {:ok, _, nil} = Parser.parse("(1) + (2)", ctx, validate: false, max_depth: 1)

      assert {:error, "expression is nested too deeply (maximum depth is 1)"} =
               Parser.parse("((1)) + (2)", ctx, validate: false, max_depth: 1)
    end

    test "rejects an invalid max_depth instead of disabling the guard", %{ctx: ctx} do
      for bad <- [-1, "16", nil, 1.5] do
        assert {:error, "invalid max_depth: must be a non-negative integer"} =
                 Parser.parse(nest("1", 40), ctx, validate: false, max_depth: bad)
      end
    end
  end

  describe "parse/3 unary minus" do
    test "parses unary minus on a variable" do
      ctx = Elex.new_context(%{"x" => %Variable{value: Decimal.new(5), type: :decimal}})
      assert {:ok, {:-, {:var, "x"}}, :decimal} = Parser.parse("-x", ctx)
    end

    test "parses unary minus on a parenthesised expression" do
      ctx = Elex.new_context()
      assert {:ok, {:-, {:+, [_, _]}}, :decimal} = Parser.parse("-(1 + 2)", ctx)
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
