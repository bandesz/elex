defmodule Elex.InverterTest do
  use ExUnit.Case
  alias Elex.Inverter
  alias Elex.Parser
  alias Elex.Evaluator

  defp parse_expression(expr_string) do
    ctx =
      Elex.new_context(%{"value" => %{value: Decimal.new("0"), type: :decimal}})

    {:ok, ast, _type} = Parser.parse(expr_string, ctx)
    ast
  end

  describe "invert/2" do
    test "inverts addition: value + constant" do
      ast = parse_expression("value + 5")
      result = Inverter.invert(ast, "value")

      # Expected: value - 5
      assert result == {:-, [{:var, "value"}, Decimal.new("5")]}
    end

    test "inverts addition: constant + value" do
      ast = parse_expression("5 + value")
      result = Inverter.invert(ast, "value")

      # Expected: value - 5
      assert result == {:-, [{:var, "value"}, Decimal.new("5")]}
    end

    test "inverts subtraction: value - constant" do
      ast = parse_expression("value - 3")
      result = Inverter.invert(ast, "value")

      # Expected: value + 3
      assert result == {:+, [{:var, "value"}, Decimal.new("3")]}
    end

    test "inverts subtraction: constant - value" do
      ast = parse_expression("10 - value")
      result = Inverter.invert(ast, "value")

      # Expected: 10 - value (becomes: -value + 10)
      assert result == {:-, [Decimal.new("10"), {:var, "value"}]}
    end

    test "inverts multiplication: value * constant" do
      ast = parse_expression("value * 4")
      result = Inverter.invert(ast, "value")

      # Expected: value / 4
      assert result == {:/, [{:var, "value"}, Decimal.new("4")]}
    end

    test "inverts multiplication: constant * value" do
      ast = parse_expression("2 * value")
      result = Inverter.invert(ast, "value")

      # Expected: value / 2
      assert result == {:/, [{:var, "value"}, Decimal.new("2")]}
    end

    test "inverts division: value / constant" do
      ast = parse_expression("value / 2")
      result = Inverter.invert(ast, "value")

      # Expected: value * 2
      assert result == {:*, [{:var, "value"}, Decimal.new("2")]}
    end

    test "inverts division: constant / value" do
      ast = parse_expression("100 / value")
      result = Inverter.invert(ast, "value")

      # Expected: 100 / value (becomes: value = 100 / result)
      assert result == {:/, [Decimal.new("100"), {:var, "value"}]}
    end

    test "returns the variable unchanged if expression is just the variable" do
      ast = parse_expression("value")
      result = Inverter.invert(ast, "value")

      assert result == {:var, "value"}
    end

    test "returns literal unchanged if expression doesn't contain the variable" do
      ast = Decimal.new("42")
      result = Inverter.invert(ast, "value")

      assert result == Decimal.new("42")
    end

    test "handles negative constants correctly" do
      ast = parse_expression("value + -5")
      result = Inverter.invert(ast, "value")

      # Expected: value - (-5) = value + 5
      assert result == {:-, [{:var, "value"}, Decimal.new("-5")]}
    end

    test "fails with multiple variables" do
      ctx =
        Elex.new_context(%{
          "x" => %{value: Decimal.new("0"), type: :decimal},
          "y" => %{value: Decimal.new("0"), type: :decimal}
        })

      {:ok, ast, _type} = Parser.parse("x + y", ctx)

      assert_raise RuntimeError, ~r/Expression contains multiple variables/, fn ->
        Inverter.invert(ast, "x")
      end
    end

    test "fails with unsupported operations" do
      ctx =
        Elex.new_context(%{
          "x" => %{value: true, type: :boolean}
        })

      {:ok, ast, _type} = Parser.parse("not x", ctx)

      assert_raise RuntimeError, ~r/Unsupported operation for inversion/, fn ->
        Inverter.invert(ast, "x")
      end
    end

    test "fails when target variable not found in expression" do
      ast = parse_expression("value + 5")

      assert_raise RuntimeError, ~r/Target variable 'missing' not found in expression/, fn ->
        Inverter.invert(ast, "missing")
      end
    end

    test "fails when trying to divide by zero" do
      # This would be value * 0, which should invert to value / 0
      ast = parse_expression("value * 0")

      assert_raise RuntimeError, ~r/Cannot invert: division by zero/, fn ->
        Inverter.invert(ast, "value")
      end
    end
  end

  describe "complex expressions (nested operations)" do
    test "handles chained additions: value + 1 + 2" do
      ast = parse_expression("value + 1 + 2")
      result = Inverter.invert(ast, "value")

      # This is ((value + 1) + 2), so we solve algebraically:
      # (value + 1) + 2 = result
      # (value + 1) = result - 2  (subtract 2 from both sides)
      # value = (result - 2) - 1  (subtract 1 from both sides)
      # This is mathematically equivalent to value = result - 3
      expected = {:-, [{:-, [{:var, "value"}, Decimal.new("2")]}, Decimal.new("1")]}
      assert result == expected
    end

    test "handles mixed operations: value * 2 + 3" do
      ast = parse_expression("value * 2 + 3")
      result = Inverter.invert(ast, "value")

      # This should be: (value - 3) / 2
      expected = {:/, [{:-, [{:var, "value"}, Decimal.new("3")]}, Decimal.new("2")]}
      assert result == expected
    end

    test "handles order of operations: 2 + value * 3" do
      ast = parse_expression("2 + value * 3")
      result = Inverter.invert(ast, "value")

      # This should be: (value - 2) / 3
      expected = {:/, [{:-, [{:var, "value"}, Decimal.new("2")]}, Decimal.new("3")]}
      assert result == expected
    end
  end

  describe "real-world examples" do
    test "Celsius to Fahrenheit conversion: celsius * 9/5 + 32" do
      # F = C * 9/5 + 32, solve for C
      # Expected: C = (F - 32) * 5/9
      ctx =
        Elex.new_context(%{
          "value" => %{value: Decimal.new("0"), type: :decimal}
        })

      {:ok, ast, _type} = Parser.parse("value * 9 / 5 + 32", ctx)
      result = Inverter.invert(ast, "value")

      # Step by step algebra:
      # celsius * 9 / 5 + 32 = fahrenheit
      # celsius * 9 / 5 = fahrenheit - 32  (subtract 32)
      # celsius * 9 = (fahrenheit - 32) * 5  (multiply by 5)
      # celsius = ((fahrenheit - 32) * 5) / 9  (divide by 9)
      expected =
        {:/,
         [{:*, [{:-, [{:var, "value"}, Decimal.new("32")]}, Decimal.new("5")]}, Decimal.new("9")]}

      assert result == expected

      # Let's also verify this works numerically:
      # 100°C should equal 212°F
      # So if we have F=212, our inverted formula should give us C=100
      # ((212 - 32) * 5) / 9 = (180 * 5) / 9 = 900 / 9 = 100 ✓

      # Test the inversion: if F=212, then C should be 100
      fahrenheit_ctx =
        Elex.new_context(%{
          "value" => %{value: Decimal.new("212"), type: :decimal}
        })

      celsius_result = Evaluator.evaluate(result, fahrenheit_ctx)
      assert Decimal.equal?(celsius_result, Decimal.new("100"))

      # Test another common conversion: 0°C = 32°F
      # So if F=32, then C should be 0
      freezing_ctx =
        Elex.new_context(%{
          "value" => %{value: Decimal.new("32"), type: :decimal}
        })

      celsius_freezing = Evaluator.evaluate(result, freezing_ctx)
      assert Decimal.equal?(celsius_freezing, Decimal.new("0"))
    end
  end
end
