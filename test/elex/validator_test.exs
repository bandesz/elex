defmodule Elex.ValidatorTest do
  use ExUnit.Case, async: true

  alias Elex.Validator

  # Test function modules with different arities
  defmodule TestFunc0 do
    @behaviour Elex.Function
    def signature, do: %{name: :test_func, arity: 0}
    def validate([], _ctx), do: {:ok, :decimal}
    def call([]), do: {:ok, Decimal.new(42)}
    def documentation, do: %{signature: "test_func()", description: "Test function"}
  end

  defmodule TestFunc1 do
    @behaviour Elex.Function
    def signature, do: %{name: :test_func, arity: 1}

    def validate([arg_ast], ctx) do
      case Validator.validate(arg_ast, ctx) do
        {:ok, :decimal} -> {:ok, :decimal}
        {:ok, _} -> {:error, "test_func expects decimal"}
        error -> error
      end
    end

    def call([arg]), do: {:ok, arg}
    def documentation, do: %{signature: "test_func(x)", description: "Test function"}
  end

  defmodule TestFunc3 do
    @behaviour Elex.Function
    def signature, do: %{name: :test_func, arity: 3}

    def validate([arg1, arg2, arg3], ctx) do
      with {:ok, :decimal} <- Validator.validate(arg1, ctx),
           {:ok, :decimal} <- Validator.validate(arg2, ctx),
           {:ok, :decimal} <- Validator.validate(arg3, ctx) do
        {:ok, :decimal}
      end
    end

    def call([arg1, arg2, arg3]), do: {:ok, Decimal.add(Decimal.add(arg1, arg2), arg3)}
    def documentation, do: %{signature: "test_func(x, y, z)", description: "Test function"}
  end

  describe "validate/2 function arity errors" do
    test "returns error for unknown function" do
      ctx = Elex.new_context()

      assert {:error, "unknown function unknown_func/1"} =
               Validator.validate({:func, "unknown_func", 1, [Decimal.new(1)]}, ctx)
    end

    test "returns 'expects no arguments' for 0-arity function called with args" do
      ctx = %{Elex.new_context() | functions: %{{"test_func", 0} => TestFunc0}}

      assert {:error, "test_func function expects no arguments"} =
               Validator.validate({:func, "test_func", 1, [Decimal.new(1)]}, ctx)
    end

    test "returns 'expects 1 argument' for 1-arity function called with wrong arity" do
      ctx = %{Elex.new_context() | functions: %{{"test_func", 1} => TestFunc1}}

      assert {:error, "test_func function expects 1 argument"} =
               Validator.validate({:func, "test_func", 0, []}, ctx)

      assert {:error, "test_func function expects 1 argument"} =
               Validator.validate({:func, "test_func", 2, [Decimal.new(1), Decimal.new(2)]}, ctx)
    end

    test "returns 'expects X or Y arguments' for function with multiple arities" do
      ctx = %{
        Elex.new_context()
        | functions: %{
            {"test_func", 0} => TestFunc0,
            {"test_func", 1} => TestFunc1,
            {"test_func", 3} => TestFunc3
          }
      }

      # Called with arity 2, but only 0, 1, and 3 are available
      assert {:error, "test_func function expects 0, 1 or 3 arguments"} =
               Validator.validate({:func, "test_func", 2, [Decimal.new(1), Decimal.new(2)]}, ctx)
    end

    test "returns 'expects X or Y arguments' for function with two arities" do
      ctx = %{
        Elex.new_context()
        | functions: %{
            {"test_func", 1} => TestFunc1,
            {"test_func", 3} => TestFunc3
          }
      }

      # Called with arity 2, but only 1 and 3 are available
      assert {:error, "test_func function expects 1 or 3 arguments"} =
               Validator.validate({:func, "test_func", 2, [Decimal.new(1), Decimal.new(2)]}, ctx)
    end
  end

  describe "validate/2 variables and literals" do
    test "rejects a reserved keyword used as a variable name" do
      ctx = Elex.new_context()

      assert {:error, "variable 'and' is a reserved keyword"} =
               Validator.validate({:var, "and"}, ctx)
    end

    test "validates a decimal literal directly" do
      ctx = Elex.new_context()
      assert {:ok, :decimal} = Validator.validate(Decimal.new("1.5"), ctx)
    end
  end

  describe "validate/2 not operator" do
    test "returns error with human-readable label for non-boolean operand" do
      ctx = Elex.new_context()

      assert {:error, "not operator can not be used on number value"} =
               Validator.validate({:not, Decimal.new(1)}, ctx)
    end
  end
end
