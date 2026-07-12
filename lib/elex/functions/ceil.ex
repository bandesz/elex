defmodule Elex.Functions.Ceil do
  @moduledoc """
  Returns the smallest integer greater than or equal to x.

  ## Expression syntax

      ceil(3.14)
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :ceil,
      arity: 1
    }
  end

  @impl Function
  @doc false
  def validate([arg_ast], context) do
    alias Elex.Validator

    case Validator.validate(arg_ast, context) do
      {:ok, :decimal} -> {:ok, :decimal}
      {:ok, other_type} -> {:error, "ceil function expects a number argument, got #{other_type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([arg]) when is_struct(arg, Decimal) do
    {:ok, Decimal.round(arg, 0, :ceiling)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "ceil(x)",
      description: "returns the smallest integer greater than or equal to x"
    }
  end
end
