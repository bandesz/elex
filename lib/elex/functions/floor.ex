defmodule Elex.Functions.Floor do
  @moduledoc """
  Returns the largest integer less than or equal to x.

  ## Expression syntax

      floor(3.14)
  """
  @behaviour Elex.Function

  alias Elex.Function
  import Elex.Labels, only: [got: 1]

  @impl Function
  @doc false
  def signature do
    %{
      name: :floor,
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
        {:error, "floor function expects a number argument, #{got(other_type)}"}

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
    {:ok, Decimal.round(arg, 0, :floor)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "floor(x)",
      description: "returns the largest integer less than or equal to x",
      category: :math
    }
  end
end
