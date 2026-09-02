defmodule Elex.Functions.Coalesce do
  @moduledoc """
  Returns the first non-null argument.

  ## Expression syntax

      coalesce(null, 5)
      coalesce(null, null, 10)
  """
  @behaviour Elex.Function

  alias Elex.Function
  alias Elex.Validator

  @impl Function
  @doc false
  def signature do
    %{
      name: :coalesce,
      variadic: true,
      min_arity: 2,
      units: :point
    }
  end

  @impl Function
  @doc false
  def validate(args_ast, context) do
    alias Elex.Validator
    import Elex.Labels

    with {:ok, types} <- validate_all(args_ast, context, Validator),
         {:ok, result_type} <- unify_types(args_ast, types, context) do
      {:ok, result_type}
    end
  end

  @impl Function
  @doc false
  def evaluate_call(args_ast, context) do
    target = Validator.first_quantity_unit(args_ast, context)
    {:ok, eval_until_present(args_ast, target, context)}
  end

  @impl Function
  @doc false
  def call(args) do
    {:ok, Enum.find(args, &(not is_nil(&1)))}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "coalesce(a, b, ...)",
      description: "returns the first non-null argument",
      category: :string
    }
  end

  defp eval_until_present([arg_ast | rest], target, context) do
    case Elex.Evaluator.evaluate!(arg_ast, context) do
      nil -> eval_until_present(rest, target, context)
      value -> Elex.Evaluator.align_to_unit(value, target, context)
    end
  end

  defp eval_until_present([], _target, _context), do: nil

  defp validate_all(args_ast, context, validator) do
    Enum.reduce_while(args_ast, {:ok, []}, fn arg_ast, acc ->
      validate_arg(acc, arg_ast, context, validator)
    end)
  end

  defp validate_arg({:error, _} = err, _arg_ast, _context, _validator), do: {:halt, err}

  defp validate_arg({:ok, types}, arg_ast, context, validator) do
    case validator.validate(arg_ast, context) do
      {:ok, type} -> {:cont, {:ok, types ++ [type]}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp unify_types(args_ast, types, context) do
    import Elex.Labels

    {asts, kept_types} =
      args_ast
      |> Enum.zip(types)
      |> Enum.reject(fn {_ast, type} -> is_nil(type) end)
      |> Enum.unzip()

    case Validator.unify_with_literal_zero(asts, kept_types, context) do
      {:ok, type} ->
        {:ok, type}

      {:mismatch, type1, type2} ->
        {:error,
         "coalesce arguments must have the same type, got #{label(type1)} and #{label(type2)}"}
    end
  end
end
