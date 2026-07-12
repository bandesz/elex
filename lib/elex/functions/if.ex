defmodule Elex.Functions.If do
  @moduledoc """
  Returns value1 if condition is true, otherwise value2.

  ## Expression syntax

      if(x > 0, 1, -1)
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :if,
      arity: 3
    }
  end

  @impl Function
  @doc false
  def validate([cond_ast, val1_ast, val2_ast], context) do
    alias Elex.Validator

    with {:ok, :boolean} <- Validator.validate(cond_ast, context),
         {:ok, type1} <- Validator.validate(val1_ast, context),
         {:ok, type2} <- Validator.validate(val2_ast, context) do
      if type1 == type2 do
        {:ok, type1}
      else
        {:error, "if branches must have the same type, got #{type1} and #{type2}"}
      end
    else
      {:ok, cond_type} ->
        {:error, "if condition must be a boolean, got #{cond_type}"}

      {:error, reason} ->
        {:error, reason}
    end
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
      description: "returns value1 if condition is true, otherwise value2"
    }
  end
end
