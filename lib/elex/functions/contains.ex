defmodule Elex.Functions.Contains do
  @moduledoc """
  Returns whether haystack contains needle.

  ## Expression syntax

      contains("hello", "ell")
  """
  @behaviour Elex.Function

  alias Elex.Function
  import Elex.Labels

  @impl Function
  @doc false
  def signature do
    %{
      name: :contains,
      arity: 2,
      units: :none
    }
  end

  @impl Function
  @doc false
  def validate([arg1_ast, arg2_ast], context) do
    alias Elex.Validator

    with {:ok, :string} <- Validator.validate(arg1_ast, context),
         {:ok, :string} <- Validator.validate(arg2_ast, context) do
      {:ok, :boolean}
    else
      {:ok, other_type} ->
        {:error, "contains function expects string arguments, #{got(other_type)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([haystack, needle]) when is_binary(haystack) and is_binary(needle) do
    {:ok, String.contains?(haystack, needle)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "contains(haystack, needle)",
      description: "returns true when haystack contains needle",
      category: :string
    }
  end
end
