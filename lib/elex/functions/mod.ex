defmodule Elex.Functions.Mod do
  @moduledoc """
  Returns the floored modulo of a divided by b (sign follows the divisor).

  Unlike [`rem/2`](`Elex.Functions.Rem`), which keeps the sign of the dividend,
  `mod(-3, 2)` returns `1` while `rem(-3, 2)` returns `-1`.

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
    {:ok, floored_mod(arg1, arg2)}
  end

  defp floored_mod(dividend, divisor) do
    remainder = Decimal.rem(dividend, divisor)

    cond do
      Decimal.equal?(remainder, 0) ->
        remainder

      Decimal.compare(divisor, 0) == :gt and Decimal.compare(remainder, 0) == :lt ->
        Decimal.add(remainder, divisor)

      Decimal.compare(divisor, 0) == :lt and Decimal.compare(remainder, 0) == :gt ->
        Decimal.add(remainder, divisor)

      true ->
        remainder
    end
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "mod(a, b)",
      description:
        "returns the floored modulo of a divided by b (sign follows the divisor, unlike rem)"
    }
  end
end
