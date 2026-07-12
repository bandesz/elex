defmodule Elex.Functions.Length do
  @moduledoc """
  Returns the length of a string as a decimal.

  ## Expression syntax

      length("hello")
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :length,
      arity: 1
    }
  end

  @impl Function
  @doc false
  def validate([arg_ast], context) do
    alias Elex.Validator

    case Validator.validate(arg_ast, context) do
      {:ok, :string} ->
        {:ok, :decimal}

      {:ok, other_type} ->
        {:error, "length function expects a string argument, got #{other_type}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([s]) when is_binary(s) do
    {:ok, Decimal.new(String.length(s))}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "length(s)",
      description: "returns the length of a string"
    }
  end
end
