defmodule Elex.Functions.Max do
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  def signature do
    %{
      name: :max,
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
      {:ok, other_type} -> {:error, "max function expects number arguments, got #{other_type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  def call([%Decimal{} = arg1, %Decimal{} = arg2]) do
    {:ok, Decimal.max(arg1, arg2)}
  end

  @impl Function
  def documentation do
    %{
      signature: "max(a, b)",
      description: "returns the larger of a or b"
    }
  end
end
