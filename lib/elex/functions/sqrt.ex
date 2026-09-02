defmodule Elex.Functions.Sqrt do
  @moduledoc """
  Returns the square root of x.

  ## Expression syntax

      sqrt(16)
  """
  @behaviour Elex.Function

  alias Elex.Function
  import Elex.Labels, only: [got: 1]

  @impl Function
  @doc false
  def signature do
    %{
      name: :sqrt,
      arity: 1,
      units: :none
    }
  end

  @impl Function
  @doc false
  def validate([arg_ast], context) do
    alias Elex.Validator

    case Validator.validate(arg_ast, context) do
      {:ok, :decimal} -> {:ok, :decimal}
      {:ok, other_type} -> {:error, "sqrt function expects a number argument, #{got(other_type)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([arg]) when is_struct(arg, Decimal) do
    {:ok, Decimal.sqrt(arg)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "sqrt(x)",
      description: "returns the square root of x",
      category: :math
    }
  end
end
