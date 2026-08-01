defmodule Elex.Functions.Upper do
  @moduledoc """
  Returns the uppercase form of a string.

  ## Expression syntax

      upper("AbC")
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :upper,
      arity: 1
    }
  end

  @impl Function
  @doc false
  def validate([arg_ast], context) do
    alias Elex.Validator

    case Validator.validate(arg_ast, context) do
      {:ok, :string} -> {:ok, :string}
      {:ok, other_type} -> {:error, "upper function expects a string argument, got #{other_type}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([s]) when is_binary(s) do
    {:ok, String.upcase(s)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "upper(s)",
      description: "returns the uppercase form of a string",
      category: :string
    }
  end
end
