defmodule Elex.Functions.PercentAdjust do
  @moduledoc false

  alias Elex.Validator
  import Elex.Labels, only: [got: 1]

  def validate(name, [value_ast, rate_ast], context) do
    with {:ok, value_type} <- Validator.validate(value_ast, context),
         :ok <- require_numeric(name, value_type),
         {:ok, rate_type} <- Validator.validate(rate_ast, context),
         :ok <- require_percent_rate(name, rate_type) do
      {:ok, value_type}
    end
  end

  def call(direction, [value, %Elex.Percent{value: points}]) do
    factor =
      case direction do
        :inc -> Decimal.add(hundred(), points)
        :dec -> Decimal.sub(hundred(), points)
      end

    scale(value, factor)
  end

  defp require_numeric(name, type) do
    if Validator.numeric_type?(type) do
      :ok
    else
      {:error, "#{name} function expects a number argument, #{got(type)}"}
    end
  end

  defp require_percent_rate(_name, :percent), do: :ok

  defp require_percent_rate(name, type) do
    {:error, "#{name} function expects a percent rate, #{got(type)}"}
  end

  defp scale(%Elex.Quantity{value: value, unit: unit}, factor) do
    {:ok, scaled} = scale(value, factor)
    {:ok, %Elex.Quantity{value: scaled, unit: unit}}
  end

  defp scale(%Elex.Percent{value: points}, factor) do
    {:ok,
     %Elex.Percent{
       value: points |> Decimal.mult(factor) |> Decimal.div(hundred()) |> Decimal.normalize()
     }}
  end

  defp scale(value, factor) when is_integer(value), do: scale(Decimal.new(value), factor)
  defp scale(value, factor) when is_float(value), do: scale(Decimal.from_float(value), factor)

  defp scale(%Decimal{} = value, factor) do
    {:ok, value |> Decimal.mult(factor) |> Decimal.div(hundred())}
  end

  defp hundred, do: Decimal.new(100)
end
