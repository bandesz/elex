defmodule Elex.Functions.Max do
  @moduledoc """
  Returns the larger of two or more values.

  ## Expression syntax

      max(3, 7)
      max(3, 7, 9)
  """
  @behaviour Elex.Function

  alias Elex.Function
  alias Elex.Validator

  @impl Function
  @doc false
  def signature do
    %{
      name: :max,
      variadic: true,
      min_arity: 2
    }
  end

  @impl Function
  @doc false
  def validate(args_ast, context) do
    case validate_all_decimal(args_ast, context) do
      :ok -> {:ok, :decimal}
      {:error, _} = err -> err
    end
  end

  defp validate_all_decimal(args_ast, context) do
    Enum.reduce_while(args_ast, :ok, fn arg_ast, :ok ->
      case Validator.validate(arg_ast, context) do
        {:ok, :decimal} ->
          {:cont, :ok}

        {:ok, other_type} ->
          {:halt, {:error, "max function expects number arguments, got #{other_type}"}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  @impl Function
  @doc false
  def call([first | rest]) do
    {:ok, Enum.reduce(rest, first, &Decimal.max/2)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "max(a, b, ...)",
      description: "returns the largest of the given values"
    }
  end
end
