defmodule Elex.Functions.Concat do
  @moduledoc """
  Concatenates zero or more strings.

  ## Expression syntax

      concat()
      concat("a")
      concat("a", "b")
      concat("a", "b", "c")
  """
  @behaviour Elex.Function

  alias Elex.Function
  alias Elex.Validator

  @impl Function
  @doc false
  def signature do
    %{
      name: :concat,
      variadic: true,
      min_arity: 0
    }
  end

  @impl Function
  @doc false
  def validate(args_ast, context) do
    case validate_all_string(args_ast, context) do
      :ok -> {:ok, :string}
      {:error, _} = err -> err
    end
  end

  defp validate_all_string(args_ast, context) do
    Enum.reduce_while(args_ast, :ok, fn arg_ast, :ok ->
      case Validator.validate(arg_ast, context) do
        {:ok, :string} ->
          {:cont, :ok}

        {:ok, other_type} ->
          {:halt, {:error, "concat function expects string arguments, got #{other_type}"}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  @impl Function
  @doc false
  def call(args) do
    {:ok, Enum.join(args)}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "concat(...)",
      description: "concatenates zero or more strings",
      category: :string
    }
  end
end
