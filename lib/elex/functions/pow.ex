defmodule Elex.Functions.Pow do
  @moduledoc """
  Returns base raised to the power of exponent.

  ## Expression syntax

      pow(2, 3)
  """
  @behaviour Elex.Function

  alias Elex.Function
  import Elex.Labels, only: [got: 1]

  @impl Function
  @doc false
  def signature do
    %{
      name: :pow,
      arity: 2,
      units: :none
    }
  end

  @impl Function
  @doc false
  def validate([arg1_ast, arg2_ast], context) do
    alias Elex.Validator

    with {:ok, base_type} <- Validator.validate(arg1_ast, context),
         {:ok, exponent_type} <- Validator.validate(arg2_ast, context) do
      validate_pow_types(base_type, exponent_type)
    end
  end

  @impl Function
  @doc false
  def call([%Elex.Percent{value: points}, %Decimal{} = exponent]) do
    {:ok, result} = call([Decimal.div(points, Decimal.new(100)), exponent])

    {:ok, %Elex.Percent{value: result |> Decimal.mult(Decimal.new(100)) |> Decimal.normalize()}}
  end

  def call([%Decimal{} = base, %Decimal{} = exponent]) do
    {:ok, pow(base, exponent)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "pow(base, exponent)",
      description: "returns base raised to the power of exponent",
      category: :math
    }
  end

  defp validate_pow_types(base_type, exponent_type) do
    cond do
      base_type not in [:decimal, :percent] ->
        {:error, "pow function expects number arguments, #{got(base_type)}"}

      exponent_type == :percent ->
        {:error, "pow function expects a number exponent, #{got(:percent)}"}

      exponent_type != :decimal ->
        {:error, "pow function expects number arguments, #{got(exponent_type)}"}

      true ->
        {:ok, base_type}
    end
  end

  defp pow(base, exponent) do
    if Decimal.integer?(exponent) do
      integer_pow(base, Decimal.to_integer(exponent))
    else
      base
      |> Decimal.to_float()
      |> :math.pow(Decimal.to_float(exponent))
      |> Decimal.from_float()
      |> Decimal.normalize()
    end
  end

  defp integer_pow(_base, 0), do: Decimal.new(1)
  defp integer_pow(base, 1), do: base

  defp integer_pow(base, exponent) when exponent > 1 do
    Enum.reduce(2..exponent, base, fn _, acc -> Decimal.mult(acc, base) end)
  end

  defp integer_pow(base, exponent) when exponent < 0 do
    Decimal.div(Decimal.new(1), integer_pow(base, abs(exponent)))
  end
end
