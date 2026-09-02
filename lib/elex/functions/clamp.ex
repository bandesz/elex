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
      arity: 3,
      units: :point
    }
  end

  @impl Function
  @doc false
  def validate(args_ast, context) do
    alias Elex.Validator

    case Validator.same_numeric_type(args_ast, context) do
      {:ok, type} ->
        {:ok, type}

      {:error, reason} ->
        {:error, reason}

      mismatch ->
        {:error, Validator.numeric_mismatch_message("clamp", mismatch)}
    end
  end

  @impl Function
  @doc false
  def call([%Elex.Quantity{unit: unit} | _] = args) do
    case call(Enum.map(args, & &1.value)) do
      {:ok, result} -> {:ok, %Elex.Quantity{value: result, unit: unit}}
      {:error, _} = err -> err
    end
  end

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
