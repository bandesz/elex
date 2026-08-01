defmodule Elex.Functions.Concat do
  @moduledoc """
  Concatenates two strings.

  ## Expression syntax

      concat("a", "b")
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :concat,
      arity: 2
    }
  end

  @impl Function
  @doc false
  def validate([arg1_ast, arg2_ast], context) do
    alias Elex.Validator

    with {:ok, :string} <- Validator.validate(arg1_ast, context),
         {:ok, :string} <- Validator.validate(arg2_ast, context) do
      {:ok, :string}
    else
      {:ok, other_type} ->
        {:error, "concat function expects string arguments, got #{other_type}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([a, b]) when is_binary(a) and is_binary(b) do
    {:ok, a <> b}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "concat(a, b)",
      description: "concatenates two strings",
      category: :string
    }
  end
end
