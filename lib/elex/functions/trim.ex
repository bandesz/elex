defmodule Elex.Functions.Trim do
  @moduledoc """
  Returns a string with leading and trailing whitespace removed.

  ## Expression syntax

      trim("  hi  ")
  """
  @behaviour Elex.Function

  alias Elex.Function
  import Elex.Labels

  @impl Function
  @doc false
  def signature do
    %{
      name: :trim,
      arity: 1,
      units: :none
    }
  end

  @impl Function
  @doc false
  def validate([arg_ast], context) do
    alias Elex.Validator

    case Validator.validate(arg_ast, context) do
      {:ok, :string} -> {:ok, :string}
      {:ok, other_type} -> {:error, "trim function expects a string argument, #{got(other_type)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([s]) when is_binary(s) do
    {:ok, String.trim(s)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "trim(s)",
      description: "returns a string with leading and trailing whitespace removed",
      category: :string
    }
  end
end
