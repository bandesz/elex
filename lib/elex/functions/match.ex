defmodule Elex.Functions.Match do
  @moduledoc """
  Returns whether text matches a regular expression pattern.

  ## Expression syntax

      match("hello123", "hello[0-9]+")
  """
  @behaviour Elex.Function

  alias Elex.Function

  @impl Function
  @doc false
  def signature do
    %{
      name: :match,
      arity: 2
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
        {:error, "match function expects string arguments, got #{other_type}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([text, pattern]) when is_binary(text) and is_binary(pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} ->
        {:ok, Regex.match?(regex, text)}

      {:error, {message, _position}} ->
        {:error, "invalid regex pattern: #{message}"}
    end
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "match(text, pattern)",
      description: "returns true when text matches the regex pattern",
      category: :string
    }
  end
end
