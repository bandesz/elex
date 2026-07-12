defmodule ElexTest do
  use ExUnit.Case, async: true

  alias Elex
  alias Elex.Variable
  alias SolidBatch.Test.Support.Elex.TestFunction

  describe "new_context/0" do
    test "creates a context with no variables" do
      ctx = Elex.new_context()
      assert ctx.variables == %{}
      assert is_map(ctx.functions)
      # Should have standard functions registered
      assert map_size(ctx.functions) > 0
    end

    test "registers all standard function names" do
      ctx = Elex.new_context()

      names =
        ctx.functions
        |> Map.keys()
        |> Enum.map(fn {name, _arity} -> name end)
        |> Enum.uniq()
        |> Enum.sort()

      assert names == [
               "abs",
               "between",
               "ceil",
               "clamp",
               "concat",
               "contains",
               "ends_with",
               "floor",
               "if",
               "length",
               "lower",
               "max",
               "min",
               "mod",
               "pi",
               "pow",
               "rem",
               "round",
               "sqrt",
               "starts_with",
               "trim",
               "upper"
             ]
    end
  end

  describe "new_context/1" do
    test "creates a context with provided variables" do
      vars = %{
        "x" => %Variable{value: Decimal.new("10"), type: :decimal},
        "y" => %Variable{value: Decimal.new("20"), type: :decimal}
      }

      ctx = Elex.new_context(vars)
      assert ctx.variables == vars
      assert map_size(ctx.functions) > 0
    end
  end

  describe "evaluate/2" do
    test "evaluates simple arithmetic expression" do
      ctx = Elex.new_context()
      assert {:ok, result} = Elex.evaluate("5 + 3", ctx)
      assert Decimal.equal?(result, Decimal.new("8"))
    end

    test "evaluates expression with variables" do
      ctx =
        Elex.new_context()
        |> Elex.add_variable("x", 10)
        |> Elex.add_variable("y", 5)

      assert {:ok, result} = Elex.evaluate("x + y", ctx)
      assert Decimal.equal?(result, Decimal.new("15"))
    end

    test "evaluates expression with functions" do
      ctx = Elex.new_context()
      assert {:ok, result} = Elex.evaluate("max(10, 20)", ctx)
      assert Decimal.equal?(result, Decimal.new("20"))
    end

    test "returns error for invalid expression" do
      ctx = Elex.new_context()
      assert {:error, _reason} = Elex.evaluate("invalid +", ctx)
    end

    test "returns error for undefined variable" do
      ctx = Elex.new_context()
      assert {:error, _reason} = Elex.evaluate("undefined_var + 5", ctx)
    end

    test "returns error on division by zero" do
      ctx = Elex.new_context()
      assert {:error, "Evaluation error: " <> _} = Elex.evaluate("10 / 0", ctx)
    end

    test "returns an error tuple when a function raises a RuntimeError" do
      ctx = %{
        Elex.new_context()
        | functions: %{{"test_func", 1} => TestFunction}
      }

      assert {:error, reason} = Elex.evaluate("test_func(666)", ctx)
      assert reason =~ "Evaluation error:"
      assert reason =~ "Simulated function error"
    end
  end

  describe "validate/2" do
    test "validates simple expression and returns type" do
      ctx = Elex.new_context()
      assert {:ok, :decimal} = Elex.validate("5 + 3", ctx)
    end

    test "validates boolean expression" do
      ctx = Elex.new_context()
      assert {:ok, :boolean} = Elex.validate("5 > 3", ctx)
    end

    test "validates string expression" do
      ctx = Elex.new_context()
      assert {:ok, :string} = Elex.validate(~s["hello"], ctx)
    end

    test "returns error for invalid expression" do
      ctx = Elex.new_context()
      assert {:error, _reason} = Elex.validate("invalid +", ctx)
    end

    test "validates expression with variables" do
      ctx =
        Elex.new_context()
        |> Elex.add_variable("x", 10)

      assert {:ok, :decimal} = Elex.validate("x + 5", ctx)
    end

    test "returns error when a reserved keyword is used as a variable" do
      ctx = Elex.new_context()
      assert {:error, "variable 'and' is a reserved keyword"} = Elex.validate("and", ctx)
    end
  end

  describe "add_variable/3" do
    test "adds decimal variable from integer" do
      ctx = Elex.new_context()
      ctx = Elex.add_variable(ctx, "x", 42)

      assert %Variable{value: value, type: :decimal} = ctx.variables["x"]
      assert value == 42
    end

    test "adds decimal variable from float" do
      ctx = Elex.new_context()
      ctx = Elex.add_variable(ctx, "x", 3.14)

      assert %Variable{value: value, type: :decimal} = ctx.variables["x"]
      assert value == 3.14
    end

    test "adds decimal variable from Decimal" do
      ctx = Elex.new_context()
      ctx = Elex.add_variable(ctx, "x", Decimal.new("99.99"))

      assert %Variable{value: value, type: :decimal} = ctx.variables["x"]
      assert Decimal.equal?(value, Decimal.new("99.99"))
    end

    test "adds string variable" do
      ctx = Elex.new_context()
      ctx = Elex.add_variable(ctx, "name", "Alice")

      assert %Variable{value: "Alice", type: :string} = ctx.variables["name"]
    end

    test "adds boolean variable" do
      ctx = Elex.new_context()
      ctx = Elex.add_variable(ctx, "flag", true)

      assert %Variable{value: true, type: :boolean} = ctx.variables["flag"]
    end

    test "adds unknown type variable" do
      ctx = Elex.new_context()
      ctx = Elex.add_variable(ctx, "unknown", :some_atom)

      assert %Variable{value: :some_atom, type: :unknown} = ctx.variables["unknown"]
    end
  end

  describe "add_variables/2" do
    test "adds multiple variables at once" do
      ctx = Elex.new_context()

      ctx =
        Elex.add_variables(ctx, %{
          "x" => 10,
          "y" => 20,
          "z" => 30
        })

      assert %Variable{value: 10, type: :decimal} = ctx.variables["x"]
      assert %Variable{value: 20, type: :decimal} = ctx.variables["y"]
      assert %Variable{value: 30, type: :decimal} = ctx.variables["z"]
    end

    test "adds variables with mixed types" do
      ctx = Elex.new_context()

      ctx =
        Elex.add_variables(ctx, %{
          "num" => 42,
          "text" => "hello",
          "flag" => true
        })

      assert %Variable{value: 42, type: :decimal} = ctx.variables["num"]
      assert %Variable{value: "hello", type: :string} = ctx.variables["text"]
      assert %Variable{value: true, type: :boolean} = ctx.variables["flag"]
    end

    test "works with empty map" do
      ctx = Elex.new_context()
      ctx = Elex.add_variables(ctx, %{})

      assert ctx.variables == %{}
    end
  end

  describe "extract_variables/1" do
    test "extracts no variables from literal expressions" do
      assert {:ok, []} = Elex.extract_variables("42")
      assert {:ok, []} = Elex.extract_variables("3.14")
      assert {:ok, []} = Elex.extract_variables("true")
      assert {:ok, []} = Elex.extract_variables("false")
      assert {:ok, []} = Elex.extract_variables("\"hello world\"")
    end

    test "extracts single variable" do
      assert {:ok, ["price"]} = Elex.extract_variables("price")
      assert {:ok, ["total_amount"]} = Elex.extract_variables("total_amount")
      assert {:ok, ["discount_rate"]} = Elex.extract_variables("discount_rate")
    end

    test "extracts variables from arithmetic expressions" do
      assert {:ok, vars} = Elex.extract_variables("price + tax")
      assert Enum.sort(vars) == ["price", "tax"]

      assert {:ok, vars} = Elex.extract_variables("base_price * quantity - discount")
      assert Enum.sort(vars) == ["base_price", "discount", "quantity"]

      assert {:ok, vars} = Elex.extract_variables("total / count")
      assert Enum.sort(vars) == ["count", "total"]
    end

    test "extracts variables from complex arithmetic expressions" do
      assert {:ok, vars} = Elex.extract_variables("(price + tax) * quantity")
      assert Enum.sort(vars) == ["price", "quantity", "tax"]

      assert {:ok, vars} = Elex.extract_variables("price * (1 + tax_rate)")
      assert Enum.sort(vars) == ["price", "tax_rate"]

      assert {:ok, vars} =
               Elex.extract_variables("base * multiplier + additional - discount")

      assert Enum.sort(vars) == ["additional", "base", "discount", "multiplier"]
    end

    test "extracts variables from comparison expressions" do
      assert {:ok, vars} = Elex.extract_variables("price > threshold")
      assert Enum.sort(vars) == ["price", "threshold"]

      assert {:ok, vars} = Elex.extract_variables("min_value <= current_value")
      assert Enum.sort(vars) == ["current_value", "min_value"]

      assert {:ok, vars} = Elex.extract_variables("start_date == end_date")
      assert Enum.sort(vars) == ["end_date", "start_date"]
    end

    test "extracts variables from logical expressions" do
      assert {:ok, vars} = Elex.extract_variables("is_active and has_permission")
      assert Enum.sort(vars) == ["has_permission", "is_active"]

      assert {:ok, vars} = Elex.extract_variables("is_valid or is_override")
      assert Enum.sort(vars) == ["is_override", "is_valid"]

      assert {:ok, vars} = Elex.extract_variables("not is_disabled")
      assert Enum.sort(vars) == ["is_disabled"]
    end

    test "extracts variables from function calls" do
      assert {:ok, vars} = Elex.extract_variables("max(price, minimum_price)")
      assert Enum.sort(vars) == ["minimum_price", "price"]

      assert {:ok, vars} =
               Elex.extract_variables("if(is_premium, premium_rate, standard_rate)")

      assert Enum.sort(vars) == ["is_premium", "premium_rate", "standard_rate"]

      assert {:ok, vars} = Elex.extract_variables("ceil(weight)")
      assert Enum.sort(vars) == ["weight"]

      assert {:ok, vars} = Elex.extract_variables("sqrt(length * width)")
      assert Enum.sort(vars) == ["length", "width"]
    end

    test "extracts variables from nested function calls" do
      assert {:ok, vars} =
               Elex.extract_variables("max(min(base_price, max_price), min_price)")

      assert Enum.sort(vars) == ["base_price", "max_price", "min_price"]

      assert {:ok, vars} =
               Elex.extract_variables("if(total > limit, max(total, penalty), total)")

      assert Enum.sort(vars) == ["limit", "penalty", "total"]
    end

    test "removes duplicate variables" do
      assert {:ok, vars} = Elex.extract_variables("price + price * tax_rate")
      assert Enum.sort(vars) == ["price", "tax_rate"]

      assert {:ok, vars} = Elex.extract_variables("max(amount, amount * multiplier)")
      assert Enum.sort(vars) == ["amount", "multiplier"]

      assert {:ok, vars} = Elex.extract_variables("if(is_valid, price, price * 0.5)")
      assert Enum.sort(vars) == ["is_valid", "price"]
    end

    test "handles complex nested expressions with multiple variables" do
      expression = "(base_price + shipping_cost) * quantity * (1 + tax_rate) - discount"
      assert {:ok, vars} = Elex.extract_variables(expression)

      assert Enum.sort(vars) == [
               "base_price",
               "discount",
               "quantity",
               "shipping_cost",
               "tax_rate"
             ]

      expression = "if(is_member, member_price * quantity, regular_price * quantity + fee)"
      assert {:ok, vars} = Elex.extract_variables(expression)
      assert Enum.sort(vars) == ["fee", "is_member", "member_price", "quantity", "regular_price"]
    end

    test "handles expressions with parentheses" do
      assert {:ok, vars} = Elex.extract_variables("(price + tax) * (quantity - returned)")
      assert Enum.sort(vars) == ["price", "quantity", "returned", "tax"]

      assert {:ok, vars} = Elex.extract_variables("((base * rate) + extra) / total")
      assert Enum.sort(vars) == ["base", "extra", "rate", "total"]
    end

    test "returns error for invalid expressions" do
      assert {:error, _reason} = Elex.extract_variables("price +")
      assert {:error, _reason} = Elex.extract_variables("* quantity")
      assert {:error, _reason} = Elex.extract_variables("price + + tax")
      assert {:error, _reason} = Elex.extract_variables("if(price")
    end

    test "handles expressions with no variables" do
      assert {:ok, []} = Elex.extract_variables("42 + 3.14")
      assert {:ok, []} = Elex.extract_variables("true and false")
      assert {:ok, []} = Elex.extract_variables("max(100, 200)")
      assert {:ok, []} = Elex.extract_variables(~s["hello" == "world"])
    end

    test "handles edge cases with single characters and underscores" do
      assert {:ok, ["a"]} = Elex.extract_variables("a")
      assert {:ok, ["x"]} = Elex.extract_variables("x + 1")
      assert {:ok, ["my_var"]} = Elex.extract_variables("my_var")
      assert {:ok, ["var_123"]} = Elex.extract_variables("var_123")
      assert {:ok, ["a1_b2_c3"]} = Elex.extract_variables("a1_b2_c3")
    end

    test "handles mixed literal and variable expressions" do
      assert {:ok, vars} = Elex.extract_variables("price + 10")
      assert vars == ["price"]

      assert {:ok, vars} = Elex.extract_variables("100 - discount")
      assert vars == ["discount"]

      assert {:ok, vars} = Elex.extract_variables("if(true, variable, 0)")
      assert vars == ["variable"]

      assert {:ok, vars} = Elex.extract_variables("max(variable, 100)")
      assert vars == ["variable"]
    end
  end
end
