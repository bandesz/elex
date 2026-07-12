defmodule Elex.EvaluatorTest do
  use ExUnit.Case, async: true

  alias Elex
  alias Elex.{Evaluator, Parser, Variable}

  defp parse_and_evaluate(expression, ctx \\ Elex.new_context()) do
    case Parser.parse(expression, ctx) do
      {:ok, ast, _type} ->
        Evaluator.evaluate(ast, ctx)

      {:error, reason} ->
        flunk("Parsing and evaluation failed unexpectedly: #{reason}")
    end
  end

  defp assert_parse_error(expression, ctx \\ Elex.new_context()) do
    assert {:error, _reason} = Parser.parse(expression, ctx)
  end

  describe "evaluate/2 with parser" do
    test "evaluates integer decimal literals" do
      assert parse_and_evaluate("-12") == Decimal.new("-12")
      assert parse_and_evaluate("-1") == Decimal.new("-1")
      assert parse_and_evaluate("0") == Decimal.new("0")
      assert parse_and_evaluate("1") == Decimal.new("1")
      assert parse_and_evaluate("12") == Decimal.new("12")
    end

    test "evaluates decimal literals" do
      assert parse_and_evaluate("-0.1") == Decimal.new("-0.1")
      assert parse_and_evaluate("-1.2") == Decimal.new("-1.2")
      assert parse_and_evaluate("-12.34") == Decimal.new("-12.34")
      assert parse_and_evaluate("0.1") == Decimal.new("0.1")
      assert parse_and_evaluate("1.2") == Decimal.new("1.2")
      assert parse_and_evaluate("12.34") == Decimal.new("12.34")
    end

    test "evaluates boolean literals" do
      assert parse_and_evaluate("true") == true
      assert parse_and_evaluate("false") == false
    end

    test "evaluates yes/no boolean aliases" do
      assert parse_and_evaluate("yes") == true
      assert parse_and_evaluate("no") == false
    end

    test "comparison binds tighter than and" do
      assert parse_and_evaluate("1 < 2 and 3 < 4") == true
      assert parse_and_evaluate("1 < 2 and 3 > 4") == false
      assert parse_and_evaluate("2 < 1 and 3 < 4") == false
    end

    test "evaluates string literals" do
      assert parse_and_evaluate("\"hello\"") == "hello"
      assert parse_and_evaluate("\"hello world\"") == "hello world"
      assert parse_and_evaluate("\"\"") == ""
      assert parse_and_evaluate(~s["hello \\"world\\""]) == "hello \"world\""
      assert parse_and_evaluate(~s["a \\" b \\" c"]) == "a \" b \" c"
      assert parse_and_evaluate("\"\\\"\"") == "\""
    end

    test "evaluates unary negation (not)" do
      assert parse_and_evaluate("not true") == false
      assert parse_and_evaluate("not false") == true
      assert parse_and_evaluate("not false or true") == true
      assert parse_and_evaluate("not (false or true)") == false
    end

    test "evaluates unary minus (-)" do
      ctx = Elex.new_context(%{"x" => %Variable{value: Decimal.new(5), type: :decimal}})

      assert parse_and_evaluate("-x", ctx) == Decimal.new("-5")
      assert parse_and_evaluate("-(1 + 2)") == Decimal.new("-3")
      assert parse_and_evaluate("2 * -3") == Decimal.new("-6")
    end

    test "evaluates addition (+)" do
      assert parse_and_evaluate("10.5 + 5.2") == Decimal.new("15.7")
      assert parse_and_evaluate("10.5 + 5.2 + 3") == Decimal.new("18.7")
      assert parse_and_evaluate("(10.5 + 5.2) + 3") == Decimal.new("18.7")
      assert parse_and_evaluate("10.5 + (5.2 + 3)") == Decimal.new("18.7")
    end

    test "evaluates subtraction (-)" do
      assert parse_and_evaluate("10.5 - 5.2") == Decimal.new("5.3")
      assert parse_and_evaluate("10.5 - 5.2 - 2") == Decimal.new("3.3")
      assert parse_and_evaluate("(10.5 - 5.2) - 2") == Decimal.new("3.3")
      assert parse_and_evaluate("10.5 - (5.2 - 2)") == Decimal.new("7.3")
    end

    test "evaluates a mix of addition and subtraction" do
      assert parse_and_evaluate("10.5 - 5.5 + 2 - 1") == Decimal.new("6.0")
    end

    test "evaluates multiplication (*)" do
      assert parse_and_evaluate("10.5 * 2") == Decimal.new("21.0")
      assert parse_and_evaluate("10.5 * 2 * 3") == Decimal.new("63.0")
      assert parse_and_evaluate("(10.5 * 2) * 3") == Decimal.new("63.0")
      assert parse_and_evaluate("10.5 * (2 * 3)") == Decimal.new("63.0")
    end

    test "evaluates division (/)" do
      assert parse_and_evaluate("10.5 / 2") == Decimal.new("5.25")
      assert parse_and_evaluate("10.5 / 2 / 0.5") == Decimal.new("10.5")
      assert parse_and_evaluate("(10.5 / 2) / 0.5") == Decimal.new("10.5")
      assert parse_and_evaluate("10.5 / (2 / 0.5)") == Decimal.new("2.625")
    end

    test "evaluates a mix of multiplication and division" do
      assert parse_and_evaluate("10 * 2 / 4 * 3") == Decimal.new("15")
    end

    test "* has precedence over +/-" do
      assert parse_and_evaluate("1.2 * 2 + 3") == Decimal.new("5.4")
      assert parse_and_evaluate("3 + 1.2 * 2") == Decimal.new("5.4")

      assert parse_and_evaluate("1.2 * 2 - 3") == Decimal.new("-0.6")
      assert parse_and_evaluate("3 - 1.2 * 2") == Decimal.new("0.6")
    end

    test "/ has precedence over +/-" do
      assert parse_and_evaluate("2.4 / 2 + 3") == Decimal.new("4.2")
      assert parse_and_evaluate("3 + 2.4/2") == Decimal.new("4.2")

      assert parse_and_evaluate("2.4 / 2 - 3") == Decimal.new("-1.8")
      assert parse_and_evaluate("3 - 2.4 / 2") == Decimal.new("1.8")
    end

    test "evaluates variable lookup" do
      ctx =
        Elex.new_context(%{
          "price" => %{value: Decimal.new("99.99"), type: :decimal},
          "quantity" => %{value: Decimal.new("3"), type: :decimal}
        })

      assert parse_and_evaluate("price", ctx) == Decimal.new("99.99")
      assert parse_and_evaluate("quantity", ctx) == Decimal.new("3")
    end

    test "returns error for missing variable during parsing" do
      assert_parse_error("non_existent")
    end

    test "evaluates nested expressions" do
      ctx =
        Elex.new_context(%{
          "price" => %{value: Decimal.new("10"), type: :decimal},
          "quantity" => %{value: Decimal.new("2"), type: :decimal},
          "tax" => %{value: Decimal.new("5.5"), type: :decimal}
        })

      expression = "price * quantity + tax"
      assert parse_and_evaluate(expression, ctx) == Decimal.new("25.5")
    end

    test "evaluates complex nested expressions" do
      ctx =
        Elex.new_context(%{
          "price" => %{value: Decimal.new("100"), type: :decimal},
          "discount" => %{value: Decimal.new("10"), type: :decimal},
          "quantity" => %{value: Decimal.new("3"), type: :decimal},
          "items" => %{value: Decimal.new("2"), type: :decimal},
          "handling_fee" => %{value: Decimal.new("5"), type: :decimal}
        })

      expression = "(price - discount) * quantity / items + handling_fee"
      assert parse_and_evaluate(expression, ctx) == Decimal.new("140")
    end

    test "evaluates less than (<)" do
      assert parse_and_evaluate("1 < 2") == true
      assert parse_and_evaluate("2 < 1") == false
      assert parse_and_evaluate("1 < 1") == false
      assert parse_and_evaluate("1.1 < 1.2") == true
      assert parse_and_evaluate("1.2 < 1.1") == false
      assert parse_and_evaluate("1.1 < 1.1") == false
    end

    test "evaluates greater than (>)" do
      assert parse_and_evaluate("1 > 2") == false
      assert parse_and_evaluate("2 > 1") == true
      assert parse_and_evaluate("1 > 1") == false
      assert parse_and_evaluate("1.1 > 1.2") == false
      assert parse_and_evaluate("1.2 > 1.1") == true
      assert parse_and_evaluate("1.1 > 1.1") == false
    end

    test "evaluates less than or equal to (<=)" do
      assert parse_and_evaluate("1 <= 2") == true
      assert parse_and_evaluate("2 <= 1") == false
      assert parse_and_evaluate("1 <= 1") == true
      assert parse_and_evaluate("1.1 <= 1.2") == true
      assert parse_and_evaluate("1.2 <= 1.1") == false
      assert parse_and_evaluate("1.1 <= 1.1") == true
    end

    test "evaluates greater than or equal to (>=)" do
      assert parse_and_evaluate("1 >= 2") == false
      assert parse_and_evaluate("2 >= 1") == true
      assert parse_and_evaluate("1 >= 1") == true
      assert parse_and_evaluate("1.1 >= 1.2") == false
      assert parse_and_evaluate("1.2 >= 1.1") == true
      assert parse_and_evaluate("1.1 >= 1.1") == true
    end

    test "evaluates comparison operators with variables" do
      ctx =
        Elex.new_context(%{
          "a" => %{value: Decimal.new("10"), type: :decimal},
          "b" => %{value: Decimal.new("20"), type: :decimal},
          "c" => %{value: Decimal.new("10"), type: :decimal}
        })

      assert parse_and_evaluate("a < b", ctx) == true
      assert parse_and_evaluate("b < a", ctx) == false
      assert parse_and_evaluate("a < c", ctx) == false

      assert parse_and_evaluate("a > b", ctx) == false
      assert parse_and_evaluate("b > a", ctx) == true
      assert parse_and_evaluate("a > c", ctx) == false

      assert parse_and_evaluate("a <= b", ctx) == true
      assert parse_and_evaluate("b <= a", ctx) == false
      assert parse_and_evaluate("a <= c", ctx) == true

      assert parse_and_evaluate("a >= b", ctx) == false
      assert parse_and_evaluate("b >= a", ctx) == true
      assert parse_and_evaluate("a >= c", ctx) == true
    end

    test "evaluates equals (==)" do
      assert parse_and_evaluate("1 == 2") == false
      assert parse_and_evaluate("1 == 1") == true
      assert parse_and_evaluate("1.1 == 1.2") == false
      assert parse_and_evaluate("1.1 == 1.1") == true
      assert parse_and_evaluate("1 == 1.0") == true

      assert parse_and_evaluate("true == true") == true
      assert parse_and_evaluate("false == false") == true
      assert parse_and_evaluate("true == false") == false

      assert parse_and_evaluate(~s["a" == "a"]) == true
      assert parse_and_evaluate(~s["a" == "b"]) == false
      assert parse_and_evaluate(~s["" == ""]) == true
    end

    test "evaluates not equals (!=)" do
      assert parse_and_evaluate("1 != 2") == true
      assert parse_and_evaluate("1 != 1") == false
      assert parse_and_evaluate("1.1 != 1.2") == true
      assert parse_and_evaluate("1.1 != 1.1") == false
      assert parse_and_evaluate("1 != 1.0") == false

      assert parse_and_evaluate("true != true") == false
      assert parse_and_evaluate("false != false") == false
      assert parse_and_evaluate("true != false") == true

      assert parse_and_evaluate(~s["a" != "a"]) == false
      assert parse_and_evaluate(~s["a" != "b"]) == true
      assert parse_and_evaluate(~s["" != ""]) == false
    end

    test "evaluates equality operators with variables" do
      ctx =
        Elex.new_context(%{
          "a" => %{value: Decimal.new("10"), type: :decimal},
          "b" => %{value: Decimal.new("20"), type: :decimal},
          "c" => %{value: Decimal.new("10"), type: :decimal},
          "t" => %{value: true, type: :boolean},
          "f" => %{value: false, type: :boolean}
        })

      assert parse_and_evaluate("a == b", ctx) == false
      assert parse_and_evaluate("a == c", ctx) == true
      assert parse_and_evaluate("a != b", ctx) == true
      assert parse_and_evaluate("a != c", ctx) == false

      assert parse_and_evaluate("t == t", ctx) == true
      assert parse_and_evaluate("f == f", ctx) == true
      assert parse_and_evaluate("t == f", ctx) == false
      assert parse_and_evaluate("t != t", ctx) == false
      assert parse_and_evaluate("f != f", ctx) == false
      assert parse_and_evaluate("t != f", ctx) == true

      ctx =
        Elex.new_context(%{
          "s1" => %{value: "hello", type: :string},
          "s2" => %{value: "world", type: :string},
          "s3" => %{value: "hello", type: :string}
        })

      assert parse_and_evaluate("s1 == s2", ctx) == false
      assert parse_and_evaluate("s1 == s3", ctx) == true
      assert parse_and_evaluate("s1 != s2", ctx) == true
      assert parse_and_evaluate("s1 != s3", ctx) == false
    end

    test "evaluates logical AND (and)" do
      assert parse_and_evaluate("true and true") == true
      assert parse_and_evaluate("true and false") == false
      assert parse_and_evaluate("false and true") == false
      assert parse_and_evaluate("false and false") == false
    end

    test "evaluates logical OR (or)" do
      assert parse_and_evaluate("true or true") == true
      assert parse_and_evaluate("true or false") == true
      assert parse_and_evaluate("false or true") == true
      assert parse_and_evaluate("false or false") == false
    end

    test "evaluates combined logical operators" do
      assert parse_and_evaluate("true and true or false") == true
      assert parse_and_evaluate("true or false and false") == true
      assert parse_and_evaluate("false and (true or false)") == false
      assert parse_and_evaluate("true or (false and false)") == true
    end

    test "evaluates logical operators with variables" do
      ctx =
        Elex.new_context(%{
          "t1" => %{value: true, type: :boolean},
          "t2" => %{value: true, type: :boolean},
          "f1" => %{value: false, type: :boolean},
          "f2" => %{value: false, type: :boolean}
        })

      assert parse_and_evaluate("t1 and t2", ctx) == true
      assert parse_and_evaluate("t1 and f1", ctx) == false
      assert parse_and_evaluate("f1 and t1", ctx) == false
      assert parse_and_evaluate("f1 and f2", ctx) == false

      assert parse_and_evaluate("t1 or t2", ctx) == true
      assert parse_and_evaluate("t1 or f1", ctx) == true
      assert parse_and_evaluate("f1 or t1", ctx) == true
      assert parse_and_evaluate("f1 or f2", ctx) == false

      assert parse_and_evaluate("t1 and t2 or f1", ctx) == true

      assert parse_and_evaluate("f1 or t1 and f2", ctx) == false
    end

    test "returns error for arithmetic operators with incompatible types during parsing" do
      assert_parse_error("1 + true")
      assert_parse_error("true + 1")
      assert_parse_error("1 - true")
      assert_parse_error("true - 1")
      assert_parse_error("1 * true")
      assert_parse_error("true * 1")
      assert_parse_error("1 / true")
      assert_parse_error("true / 1")

      assert_parse_error(~s["a" + "b"])
      assert_parse_error(~s[1 + "b"])
      assert_parse_error(~s["a" + 1])
      assert_parse_error(~s["a" - "b"])
      assert_parse_error(~s[1 - "b"])
      assert_parse_error(~s["a" - 1])
      assert_parse_error(~s["a" * "b"])
      assert_parse_error(~s[1 * "b"])
      assert_parse_error(~s["a" * 1])
      assert_parse_error(~s["a" / "b"])
      assert_parse_error(~s[1 / "b"])
      assert_parse_error(~s["a" / 1])
    end

    test "returns error for comparison operators with incompatible types during parsing" do
      assert_parse_error("1 < true")
      assert_parse_error("true < 1")
      assert_parse_error("1 > true")
      assert_parse_error("true > 1")
      assert_parse_error("1 <= true")
      assert_parse_error("true <= 1")
      assert_parse_error("1 >= true")
      assert_parse_error("true >= 1")

      assert_parse_error(~s["a" < "b"])
      assert_parse_error(~s[1 < "b"])
      assert_parse_error(~s["a" < 1])
      assert_parse_error(~s["a" > "b"])
      assert_parse_error(~s[1 > "b"])
      assert_parse_error(~s["a" > 1])
      assert_parse_error(~s["a" <= "b"])
      assert_parse_error(~s[1 <= "b"])
      assert_parse_error(~s["a" <= 1])
      assert_parse_error(~s["a" >= "b"])
      assert_parse_error(~s[1 >= "b"])
      assert_parse_error(~s["a" >= 1])
    end

    test "returns error for equality operators with incompatible types during parsing" do
      assert_parse_error("1 == true")
      assert_parse_error("true == 1")
      assert_parse_error("1 != true")
      assert_parse_error("true != 1")

      assert_parse_error(~s["a" == true])
      assert_parse_error(~s[true == "a"])
      assert_parse_error(~s["a" != true])
      assert_parse_error(~s[true != "a"])
      assert_parse_error(~s["a" == 1])
      assert_parse_error(~s[1 == "a"])
      assert_parse_error(~s["a" != 1])
      assert_parse_error(~s[1 != "a"])
    end

    test "returns error for logical operators with incompatible types during parsing" do
      assert_parse_error("true and 1")
      assert_parse_error("1 and true")
      assert_parse_error("1 and 2")
      assert_parse_error("false or 1")
      assert_parse_error("1 or false")
      assert_parse_error("1 or 2")

      ctx_decimal = Elex.new_context(%{"d" => %{value: Decimal.new(1), type: :decimal}})
      assert_parse_error("true and d", ctx_decimal)
      assert_parse_error("d and true", ctx_decimal)
      assert_parse_error("false or d", ctx_decimal)
      assert_parse_error("d or false", ctx_decimal)

      assert_parse_error(~s[true and "a"])
      assert_parse_error(~s["a" and true])
      assert_parse_error(~s["a" and "b"])
      assert_parse_error(~s[false or "a"])
      assert_parse_error(~s["a" or false])
      assert_parse_error(~s["a" or "b"])
    end

    test "returns error for unary negation (not) on incompatible types during parsing" do
      assert_parse_error("not 123")

      assert_parse_error(
        "not a",
        Elex.new_context(%{
          "a" => %{value: Decimal.new(1), type: :decimal}
        })
      )

      assert_parse_error("not \"hello\"")

      assert_parse_error(
        "not s",
        Elex.new_context(%{
          "s" => %{value: "hello", type: :string}
        })
      )
    end

    test "returns error for unary minus on incompatible types during parsing" do
      assert_parse_error("-true")
      assert_parse_error(~s[- "hello"])

      assert_parse_error(
        "-a",
        Elex.new_context(%{
          "a" => %{value: true, type: :boolean}
        })
      )

      assert_parse_error(
        "-s",
        Elex.new_context(%{
          "s" => %{value: "hello", type: :string}
        })
      )
    end
  end

  describe "short-circuit evaluation" do
    test "and does not evaluate the right operand when the left is false" do
      assert parse_and_evaluate("false and (1 / 0 > 0)") == false
    end

    test "and evaluates the right operand when the left is true" do
      assert_raise Decimal.Error, fn -> parse_and_evaluate("true and (1 / 0 > 0)") end
    end

    test "or does not evaluate the right operand when the left is true" do
      assert parse_and_evaluate("true or (1 / 0 > 0)") == true
    end

    test "or evaluates the right operand when the left is false" do
      assert_raise Decimal.Error, fn -> parse_and_evaluate("false or (1 / 0 > 0)") end
    end
  end

  describe "function calls" do
    alias SolidBatch.Test.Support.Elex.TestFunction

    defp test_func_context(variables \\ %{}) do
      ctx = Elex.new_context(variables)
      %{ctx | functions: %{{"test_func", 1} => TestFunction}}
    end

    test "evaluates function call with literal argument" do
      ctx = test_func_context()
      assert parse_and_evaluate("test_func(123.45)", ctx) == Decimal.new("123.45")
    end

    test "evaluates function call with variable argument" do
      ctx =
        test_func_context(%{
          "dec_var" => %Variable{value: Decimal.new("9.87"), type: :decimal}
        })

      assert parse_and_evaluate("test_func(dec_var)", ctx) == Decimal.new("9.87")
    end

    test "evaluates nested function calls and expressions" do
      ctx =
        test_func_context(%{
          "price" => %Variable{value: Decimal.new("19.95"), type: :decimal},
          "qty" => %Variable{value: Decimal.new("2"), type: :decimal}
        })

      assert parse_and_evaluate("test_func(10.5 + 5.2)", ctx) == Decimal.new("15.7")
      assert parse_and_evaluate("test_func(price * qty)", ctx) == Decimal.new("39.90")
      assert parse_and_evaluate("test_func(test_func(price))", ctx) == Decimal.new("19.95")
      assert parse_and_evaluate("test_func(price) + qty", ctx) == Decimal.new("21.95")
    end

    test "returns error for unknown function during parsing" do
      assert_parse_error("unknown_func(1)")
      ctx = test_func_context()
      assert_parse_error("another_unknown_func(1)", ctx)
    end

    test "returns error for wrong number of arguments during parsing" do
      ctx = test_func_context()
      assert_parse_error("test_func()", ctx)
      assert_parse_error("test_func(1, 2)", ctx)
    end

    test "returns error for wrong argument type during parsing (if function signature enforces it)" do
      defmodule StrictFunc do
        @behaviour Elex.Function
        alias Elex.Function

        @impl Function
        def signature,
          do: %{name: :strict_func, arity: 1, args: [:decimal]}

        @impl Function
        def call([arg]), do: {:ok, arg}

        def validate([arg_ast], context) do
          alias Elex.Validator

          case Validator.validate(arg_ast, context) do
            {:ok, :decimal} ->
              {:ok, :decimal}

            {:ok, other_type} ->
              {:error, "strict_func/1 expects a number argument, got #{other_type}"}

            {:error, reason} ->
              {:error, reason}
          end
        end
      end

      ctx = %{Elex.new_context() | functions: %{{"strict_func", 1} => StrictFunc}}
      assert_parse_error("strict_func(true)", ctx)
      assert_parse_error("strict_func(\"hello\")", ctx)

      ctx_vars = %{
        Elex.new_context(%{"bool_var" => %Variable{value: true, type: :boolean}})
        | functions: %{{"strict_func", 1} => StrictFunc}
      }

      assert_parse_error("strict_func(bool_var)", ctx_vars)
    end

    test "returns error during evaluation if function returns error" do
      ctx = test_func_context()

      assert_raise RuntimeError,
                   ~r/Error calling function test_func\/1: "Simulated function error"/,
                   fn ->
                     parse_and_evaluate("test_func(666)", ctx)
                   end
    end

    test "function name is case sensitive and requires correct format" do
      ctx = test_func_context()
      assert_parse_error("Test_func(1.2)", ctx)
      assert_parse_error("test_func_1(1.2)", ctx)
    end

    test "variable name takes precedence if no parentheses" do
      ctx =
        test_func_context(%{"test_func" => %Variable{value: Decimal.new("55"), type: :decimal}})

      assert parse_and_evaluate("test_func", ctx) == Decimal.new("55")
      assert parse_and_evaluate("test_func(1.2)", ctx) == Decimal.new("1.2")
    end
  end
end
