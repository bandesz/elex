defmodule Elex.Functions.Between do
  @moduledoc """
  Returns whether x is within the inclusive range between low and high.

  ## Expression syntax

      between(5, 0, 10)
  """
  @behaviour Elex.Function

  alias Elex.Function
  alias Elex.Validator

  @impl Function
  @doc false
  def signature do
    %{
      name: :between,
      arity: 3,
      units: :point
    }
  end

  @impl Function
  @doc false
  def validate(args_ast, context) do
    case Validator.same_numeric_type(args_ast, context) do
      {:ok, _type} ->
        {:ok, :boolean}

      {:error, reason} ->
        {:error, reason}

      mismatch ->
        {:error, Validator.numeric_mismatch_message("between", mismatch)}
    end
  end

  @impl Function
  @doc false
  def call([%Elex.Quantity{} | _] = args) do
    call(Enum.map(args, & &1.value))
  end

  def call([%Decimal{} = value, %Decimal{} = low, %Decimal{} = high]) do
    if Decimal.compare(low, high) == :gt do
      {:error, "between low must be less than or equal to high"}
    else
      result =
        Decimal.compare(value, low) in [:gt, :eq] and
          Decimal.compare(value, high) in [:lt, :eq]

      {:ok, result}
    end
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "between(x, low, high)",
      description: "returns true when x is within the inclusive range between low and high",
      category: :math
    }
  end
end
