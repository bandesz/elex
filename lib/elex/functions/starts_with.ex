defmodule Elex.Functions.StartsWith do
  @moduledoc """
  Returns whether text starts with prefix.

  ## Expression syntax

      starts_with("hello", "he")
  """
  @behaviour Elex.Function

  alias Elex.Function
  import Elex.Labels

  @impl Function
  @doc false
  def signature do
    %{
      name: :starts_with,
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
        {:error, "starts_with function expects string arguments, #{got(other_type)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([text, prefix]) when is_binary(text) and is_binary(prefix) do
    {:ok, String.starts_with?(text, prefix)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "starts_with(text, prefix)",
      description: "returns true when text starts with prefix",
      category: :string
    }
  end
end
