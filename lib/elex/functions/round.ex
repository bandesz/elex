defmodule Elex.Functions.Round do
  @moduledoc """
  Returns x rounded to the nearest integer.

  ## Expression syntax

      round(3.6)
  """
  @behaviour Elex.Function

  alias Elex.Function
  import Elex.Labels, only: [got: 1]

  @impl Function
  @doc false
  def signature do
    %{
      name: :round,
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
        {:error, "round function expects a number argument, #{got(other_type)}"}

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
    {:ok, Decimal.round(arg)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "round(x)",
      description: "returns x rounded to the nearest integer",
      category: :math
    }
  end
end
