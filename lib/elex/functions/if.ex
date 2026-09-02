defmodule Elex.Functions.If do
  @moduledoc """
  Returns value1 if condition is true, otherwise value2.

  ## Expression syntax

      if(x > 0, 1, -1)
  """
  @behaviour Elex.Function

  alias Elex.Function
  alias Elex.Validator
  import Elex.Labels

  @impl Function
  @doc false
  def signature do
    %{
      name: :if,
      arity: 3,
      units: :point
    }
  end

  @impl Function
  @doc false
  def validate([cond_ast, val1_ast, val2_ast], context) do
    alias Elex.Validator

    with {:ok, :boolean} <- Validator.validate(cond_ast, context),
         {:ok, type1} <- Validator.validate(val1_ast, context),
         {:ok, type2} <- Validator.validate(val2_ast, context) do
      case Validator.unify_with_literal_zero([val1_ast, val2_ast], [type1, type2], context) do
        {:ok, type} ->
          {:ok, type}

        {:mismatch, left, right} ->
          {:error, "if branches must have the same type, got #{label(left)} and #{label(right)}"}
      end
    else
      {:ok, cond_type} ->
        {:error, "if condition must be a boolean, got #{label(cond_type)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Function
  @doc false
  def evaluate_call([cond_ast, true_ast, false_ast], context) do
    value =
      if Elex.Evaluator.evaluate!(cond_ast, context) do
        Elex.Evaluator.evaluate!(true_ast, context)
      else
        Elex.Evaluator.evaluate!(false_ast, context)
      end

    target = Validator.first_quantity_unit([cond_ast, true_ast, false_ast], context)
    {:ok, Elex.Evaluator.align_to_unit(value, target, context)}
  end

  @impl Function
  @doc false
  def call([condition, value1, value2]) do
    if condition do
      {:ok, value1}
    else
      {:ok, value2}
    end
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "if(condition, value1, value2)",
      description: "returns value1 if condition is true, otherwise value2",
      category: :math
    }
  end
end
