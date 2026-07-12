defmodule Elex.Functions.Between do
  @moduledoc """
  Returns whether x is within the inclusive range between low and high.

  ## Expression syntax

      between(5, 0, 10)
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :between,
      arity: 3
    }
  end

  @impl Function
  @doc false
  def validate([arg1_ast, arg2_ast, arg3_ast], context) do
    alias Elex.Validator

    with {:ok, :decimal} <- Validator.validate(arg1_ast, context),
         {:ok, :decimal} <- Validator.validate(arg2_ast, context),
         {:ok, :decimal} <- Validator.validate(arg3_ast, context) do
      {:ok, :boolean}
    else
      {:ok, other_type} ->
        {:error, "between function expects number arguments, got #{other_type}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([%Decimal{} = value, %Decimal{} = low, %Decimal{} = high]) do
    result =
      Decimal.compare(value, low) in [:gt, :eq] and
        Decimal.compare(value, high) in [:lt, :eq]

    {:ok, result}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "between(x, low, high)",
      description: "returns true when x is within the inclusive range between low and high"
    }
  end
end
