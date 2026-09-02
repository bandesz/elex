defmodule Elex.Functions.Convert do
  @moduledoc """
  Converts a quantity into a named unit or unit formula.

  ## Expression syntax

      convert(1m + 1mm, "mm")
  """
  @behaviour Elex.Function

  alias Elex.Context
  alias Elex.Function
  alias Elex.Quantity
  alias Elex.Validator
  import Elex.Labels

  @impl Function
  @doc false
  def signature do
    %{
      name: :convert,
      arity: 2,
      units: :convert
    }
  end

  @impl Function
  @doc false
  def validate([value_ast, unit_ast], context) do
    with {:ok, value_type} <- Validator.validate(value_ast, context),
         {:ok, unit_type} <- Validator.validate(unit_ast, context),
         :ok <- convert_arg_types(value_type, unit_type),
         {:ok, target} <- resolve_target(unit_ast, context),
         :ok <- Elex.Evaluator.validate_conversion(value_ast, value_type, target, context) do
      {:ok, value_type}
    end
  end

  @impl Function
  @doc false
  def call([%Quantity{} = quantity, to_unit], ctx \\ %Context{}) when is_binary(to_unit) do
    Elex.Evaluator.apply_target_unit(quantity, to_unit, ctx)
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "convert(value, unit)",
      description: "converts a quantity into the given unit",
      category: :math
    }
  end

  defp convert_arg_types(:decimal, _unit_type),
    do: {:error, "cannot convert a number"}

  defp convert_arg_types(value_type, unit_type) do
    cond do
      not unitful_category?(value_type) ->
        {:error, "convert function expects a unitful value, #{got(value_type)}"}

      unit_type != :string ->
        {:error, "convert function expects a string unit, #{got(unit_type)}"}

      true ->
        :ok
    end
  end

  defp unitful_category?(type) do
    Validator.numeric_type?(type) and type != :decimal
  end

  defp resolve_target(target, _context) when is_binary(target), do: {:ok, target}

  defp resolve_target({:var, name}, %{variables: variables} = context) when is_binary(name) do
    case Map.get(variables, name) do
      %{value: value} when is_binary(value) -> resolve_target(value, context)
      _ -> {:error, "convert expects a unit literal"}
    end
  end

  defp resolve_target(_unit_ast, _context), do: {:error, "convert expects a unit literal"}
end
