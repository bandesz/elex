defmodule ElexTest do
  use ExUnit.Case, async: true

  alias Elex

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
