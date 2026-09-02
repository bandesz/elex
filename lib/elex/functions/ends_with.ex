defmodule Elex.Functions.EndsWith do
  @moduledoc """
  Returns whether text ends with suffix.

  ## Expression syntax

      ends_with("hello", "lo")
  """
  @behaviour Elex.Function

  alias Elex.Function
  import Elex.Labels

  @impl Function
  @doc false
  def signature do
    %{
      name: :ends_with,
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
        {:error, "ends_with function expects string arguments, #{got(other_type)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([text, suffix]) when is_binary(text) and is_binary(suffix) do
    {:ok, String.ends_with?(text, suffix)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "ends_with(text, suffix)",
      description: "returns true when text ends with suffix",
      category: :string
    }
  end
end
