defmodule Elex.Functions.Clamp do
  @moduledoc """
  Clamps a value to the inclusive range between min and max.

  ## Expression syntax

      clamp(5, 0, 10)
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :clamp,
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
      {:ok, :decimal}
    else
      {:ok, other_type} -> {:error, "clamp function expects number arguments, got #{other_type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([%Decimal{} = value, %Decimal{} = min, %Decimal{} = max]) do
    if Decimal.compare(min, max) == :gt do
      {:error, "clamp min must be less than or equal to max"}
    else
      {:ok, value |> Decimal.max(min) |> Decimal.min(max)}
    end
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "clamp(x, min, max)",
      description: "clamps x to the inclusive range between min and max",
      category: :math
    }
  end
end
