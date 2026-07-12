defmodule Elex.Functions.Mod do
  @moduledoc """
  Returns the remainder of a divided by b.

  ## Expression syntax

      mod(10, 3)
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :mod,
      arity: 2
    }
  end

  @impl Function
  @doc false
  def validate([arg1_ast, arg2_ast], context) do
    alias Elex.Validator

    with {:ok, :decimal} <- Validator.validate(arg1_ast, context),
         {:ok, :decimal} <- Validator.validate(arg2_ast, context) do
      {:ok, :decimal}
    else
      {:ok, other_type} -> {:error, "mod function expects number arguments, got #{other_type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([%Decimal{} = arg1, %Decimal{} = arg2]) do
    {:ok, Decimal.rem(arg1, arg2)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "mod(a, b)",
      description: "returns the remainder of a divided by b"
    }
  end
end
