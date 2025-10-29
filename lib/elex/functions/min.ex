defmodule Elex.Functions.Min do
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  def signature do
    %{
      name: :min,
      arity: 2
    }
  end

  @impl Function
  def validate([arg1_ast, arg2_ast], context) do
    alias Elex.Validator

    with {:ok, :decimal} <- Validator.validate(arg1_ast, context),
         {:ok, :decimal} <- Validator.validate(arg2_ast, context) do
      {:ok, :decimal}
    else
      {:ok, other_type} -> {:error, "min function expects number arguments, got #{other_type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  def call([%Decimal{} = arg1, %Decimal{} = arg2]) do
    {:ok, Decimal.min(arg1, arg2)}
  end

  @impl Function
  def documentation do
    %{
      signature: "min(a, b)",
      description: "returns the smaller of a or b"
    }
  end
end
