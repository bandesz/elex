defmodule Elex.Parser.ErrorFormatterTest do
  use ExUnit.Case, async: true

  alias Elex.Parser.ErrorFormatter

  doctest ErrorFormatter

  describe "humanize/3 empty input" do
    test "reports an empty expression regardless of rest/offset" do
      assert ErrorFormatter.humanize("", "", 0) == "the expression is empty"
      assert ErrorFormatter.humanize("   ", "   ", 0) == "the expression is empty"
    end
  end

  describe "humanize/3 structural errors" do
    test "detects a missing closing parenthesis" do
      assert ErrorFormatter.humanize("( 1 + 2", "( 1 + 2", 0) ==
               "closing parenthesis is missing"
    end

    test "detects an unexpected closing parenthesis" do
      assert ErrorFormatter.humanize("1 + 2 )", ")", 6) == "unexpected closing parenthesis"
    end

    test "detects an unterminated string" do
      assert ErrorFormatter.humanize(~s["oops], ~s["oops], 0) == "closing quote is missing"
    end

    test "ignores parentheses that live inside a string literal" do
      # A ')' inside a string must not be treated as an unbalanced parenthesis;
      # the real problem here is the missing closing parenthesis of the group.
      assert ErrorFormatter.humanize(~s[( "a )" ], ~s[( "a )" ], 0) ==
               "closing parenthesis is missing"
    end

    test "treats an invalid backslash escape as a missing closing quote" do
      # The parser only recognises `\\"` as an escape, so a backslash followed by
      # anything else must not be scanned as a valid escape that leaves the
      # structure balanced (which previously produced `unexpected '\"'`).
      assert ErrorFormatter.humanize(~s["a\\\\"], ~s["a\\\\"], 0) ==
               "closing quote is missing"
    end

    test "treats a valid escaped quote with no closing quote as unterminated" do
      assert ErrorFormatter.humanize(~s["a\\"], ~s["a\\"], 0) == "closing quote is missing"
    end

    test "treats a trailing backslash inside a string as a missing closing quote" do
      assert ErrorFormatter.humanize(~s["a\\], ~s["a\\], 0) == "closing quote is missing"
    end
  end

  describe "humanize/3 token errors" do
    test "a value is missing after a trailing operator" do
      assert ErrorFormatter.humanize("1 +", "+", 2) == "a value is missing after '+'"
      assert ErrorFormatter.humanize("1 and", "and", 2) == "a value is missing after 'and'"
    end

    test "an expression can not start with an operator" do
      assert ErrorFormatter.humanize("* 1", "* 1", 0) == "an expression can not start with '*'"
    end

    test "empty parentheses" do
      assert ErrorFormatter.humanize("()", "()", 0) ==
               "an expression is expected inside the parentheses"
    end

    test "unexpected token falls back to the offending snippet" do
      assert ErrorFormatter.humanize("1 2", "2", 2) == "unexpected '2'"
      assert ErrorFormatter.humanize("1 & 2", "& 2", 2) == "unexpected '&'"
    end

    test "reports an incomplete expression when only whitespace remains" do
      # This branch is not reachable through `Elex.Parser.parse/3` (its grammar
      # consumes trailing whitespace before end-of-string), so it is exercised
      # directly here to document the behaviour.
      assert ErrorFormatter.humanize("1 ", " ", 1) == "the expression is incomplete"
    end
  end

  describe "humanize/3 function argument errors" do
    test "a value where a separator is expected inside a call reads as a missing comma" do
      assert ErrorFormatter.humanize("max(1 2)", "2)", 6) ==
               "arguments must be separated by commas"

      assert ErrorFormatter.humanize("foo(a b)", "b)", 6) ==
               "arguments must be separated by commas"
    end

    test "the missing-comma hint requires a function call, not a plain grouping" do
      # Same shape, but the open parenthesis is a grouping (no preceding
      # identifier), so the value token is reported literally.
      assert ErrorFormatter.humanize("(1 2)", "2)", 3) == "unexpected '2'"
    end

    test "a non-value token inside a call is reported literally" do
      assert ErrorFormatter.humanize("max(1 & 2)", "& 2)", 6) == "unexpected '&'"
    end

    test "parentheses inside a string do not count as an open call" do
      # The `(` lives inside the string literal, so there is no open function
      # call; the two adjacent values are reported literally, not as a comma.
      assert ErrorFormatter.humanize(~s["ab(" 2], "2", 6) == "unexpected '2'"
    end

    test "a group led by a reserved operator is not treated as a function call" do
      # `not (` looks like `name(` but `not` is an operator, so the grouping's
      # contents should be reported literally rather than as a missing comma.
      assert ErrorFormatter.humanize("not (a b)", "b)", 7) == "unexpected 'b'"
    end
  end
end
