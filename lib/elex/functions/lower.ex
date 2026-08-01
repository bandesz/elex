defmodule Elex.Functions.Lower do
  @moduledoc """
  Returns the lowercase form of a string.

  ## Expression syntax

      lower("AbC")
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :lower,
      arity: 1
    }
  end

  @impl Function
  @doc false
  def validate([arg_ast], context) do
    alias Elex.Validator

    case Validator.validate(arg_ast, context) do
      {:ok, :string} -> {:ok, :string}
      {:ok, other_type} -> {:error, "lower function expects a string argument, got #{other_type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([s]) when is_binary(s) do
    {:ok, String.downcase(s)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "lower(s)",
      description: "returns the lowercase form of a string",
      category: :string
    }
  end
end
