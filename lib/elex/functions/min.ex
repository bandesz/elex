defmodule Elex.Functions.Min do
  @moduledoc """
  Returns the smaller of two or more values.

  ## Expression syntax

      min(3, 7)
      min(3, 7, 1)
  """
  @behaviour Elex.Function

  alias Elex.Function
  alias Elex.Validator

  @impl Function
  @doc false
  def signature do
    %{
      name: :min,
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
          {:halt, {:error, "min function expects number arguments, got #{other_type}"}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  @impl Function
  @doc false
  def call([first | rest]) do
    {:ok, Enum.reduce(rest, first, &Decimal.min/2)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "min(a, b, ...)",
      description: "returns the smallest of the given values"
    }
  end
end
