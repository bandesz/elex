defmodule Elex.Functions.Round do
  @moduledoc """
  Returns x rounded to the nearest integer.

  ## Expression syntax

      round(3.6)
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :round,
      arity: 1
    }
  end

  @impl Function
  @doc false
  def validate([arg_ast], context) do
    alias Elex.Validator

    case Validator.validate(arg_ast, context) do
      {:ok, :decimal} -> {:ok, :decimal}
      {:ok, other_type} -> {:error, "round function expects a number argument, got #{other_type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([arg]) when is_struct(arg, Decimal) do
    {:ok, Decimal.round(arg)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "round(x)",
      description: "returns x rounded to the nearest integer",
      category: :math
    }
  end
end
