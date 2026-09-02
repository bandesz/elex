defmodule Elex.Functions.Ceil do
  @moduledoc """
  Returns the smallest integer greater than or equal to x.

  ## Expression syntax

      ceil(3.14)
  """
  @behaviour Elex.Function

  alias Elex.Function
  import Elex.Labels, only: [got: 1]

  @impl Function
  @doc false
  def signature do
    %{
      name: :ceil,
      arity: 1,
      units: :point
    }
  end

  @impl Function
  @doc false
  def validate([arg_ast], context) do
    alias Elex.Validator

    case Validator.same_numeric_type([arg_ast], context) do
      {:ok, type} ->
        {:ok, type}

      {:mismatch, other_type} ->
        {:error, "ceil function expects a number argument, #{got(other_type)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([%Elex.Quantity{value: value, unit: unit}]) do
    {:ok, result} = call([value])
    {:ok, %Elex.Quantity{value: result, unit: unit}}
  end

  def call([arg]) when is_struct(arg, Decimal) do
    {:ok, Decimal.round(arg, 0, :ceiling)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "ceil(x)",
      description: "returns the smallest integer greater than or equal to x",
      category: :math
    }
  end
end
