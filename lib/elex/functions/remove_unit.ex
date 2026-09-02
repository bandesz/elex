defmodule Elex.Functions.RemoveUnit do
  @moduledoc """
  Returns the magnitude of a quantity as a number.

  ## Expression syntax

      remove_unit(2C)
  """
  @behaviour Elex.Function

  alias Elex.Context
  alias Elex.Function
  alias Elex.Quantity
  alias Elex.Validator
  import Elex.Labels, only: [got: 1]

  @impl Function
  @doc false
  def signature do
    %{
      name: :remove_unit,
      arity: 1,
      units: :unwrap
    }
  end

  @impl Function
  @doc false
  def validate([value_ast], context) do
    case Validator.validate(value_ast, context) do
      {:ok, :decimal} ->
        {:error, "cannot remove unit from a number"}

      {:ok, type} ->
        if unitful_category?(type) do
          {:ok, :decimal}
        else
          {:error, "remove_unit function expects a unitful value, #{got(type)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Function
  @doc false
  def call([%Quantity{value: value}], _ctx \\ %Context{}) do
    {:ok, value}
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "remove_unit(value)",
      description: "returns the magnitude of a quantity as a number",
      category: :math
    }
  end

  defp unitful_category?(type) do
    Validator.numeric_type?(type) and type != :decimal
  end
end
