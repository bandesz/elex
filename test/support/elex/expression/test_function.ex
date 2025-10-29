defmodule SolidBatch.Test.Support.Elex.TestFunction do
  @moduledoc """
  A simple function for testing expression evaluation logic.
  It takes one argument of any type and returns it wrapped in {:ok, ...}.
  It also simulates an error if the argument is the string "error".
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  def signature do
    %{
      name: :test_func,
      arity: 1
    }
  end

  @impl Function
  def validate([arg_ast], context) do
    alias Elex.Validator

    case Validator.validate(arg_ast, context) do
      {:ok, :decimal} -> {:ok, :decimal}
      {:ok, other_type} -> {:error, "test_func expects a number, got #{other_type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  def call([arg]) do
    if Decimal.compare(arg, 666) == :eq do
      {:error, "Simulated function error"}
    else
      {:ok, arg}
    end
  end

  @impl Function
  def documentation do
    %{
      signature: "test_func(x)",
      description: "test function with one argument"
    }
  end
end
