defmodule Elex.Functions.Abs do
  @moduledoc """
  Returns the absolute value of x.

  ## Expression syntax

      abs(-5)
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :abs,
      arity: 1
    }
  end

  @impl Function
  @doc false
  def validate([arg_ast], context) do
    alias Elex.Validator

    case Validator.validate(arg_ast, context) do
      {:ok, :decimal} -> {:ok, :decimal}
      {:ok, other_type} -> {:error, "abs function expects a number argument, got #{other_type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([arg]) when is_struct(arg, Decimal) do
    {:ok, Decimal.abs(arg)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "abs(x)",
      description: "returns the absolute value of x"
    }
  end
end
