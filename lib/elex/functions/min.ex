defmodule Elex.Functions.Min do
  @moduledoc """
  Returns the smaller of two or more values.

  ## Expression syntax

      min(3, 7)
      min(3, 7, 1)
  """
  @behaviour Elex.Function

  alias Elex.Function
  alias Elex.Validator

  @impl Function
  @doc false
  def signature do
    %{
      name: :min,
      variadic: true,
      min_arity: 2,
      units: :point
    }
  end

  @impl Function
  @doc false
  def validate(args_ast, context) do
    case Validator.same_numeric_type(args_ast, context) do
      {:ok, type} ->
        {:ok, type}

      {:error, reason} ->
        {:error, reason}

      mismatch ->
        {:error, Validator.numeric_mismatch_message("min", mismatch)}
    end
  end

  @impl Function
  @doc false
  def call([%Elex.Quantity{unit: unit} | _] = args) do
    {:ok, result} = call(Enum.map(args, & &1.value))
    {:ok, %Elex.Quantity{value: result, unit: unit}}
  end

  def call([first | rest]) do
    {:ok, Enum.reduce(rest, first, &Decimal.min/2)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "min(a, b, ...)",
      description: "returns the smallest of the given values",
      category: :math
    }
  end
end
