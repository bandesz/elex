defmodule Elex.Functions.AddUnit do
  @moduledoc """
  Wraps a number as a quantity of a registered unit symbol.

  ## Expression syntax

      add_unit(5, "C")
  """
  @behaviour Elex.Function

  alias Elex.Context
  alias Elex.Function
  alias Elex.Quantity
  alias Elex.Unit
  alias Elex.Units.Catalog
  alias Elex.Validator
  import Elex.Labels, only: [got: 1]

  @impl Function
  @doc false
  def signature do
    %{
      name: :add_unit,
      arity: 2,
      units: :wrap
    }
  end

  @impl Function
  @doc false
  def validate([value_ast, unit_ast], context) do
    with {:ok, value_type} <- Validator.validate(value_ast, context),
         {:ok, unit_type} <- Validator.validate(unit_ast, context) do
      cond do
        match?(%Elex.Dimension{}, value_type) ->
          {:error, "add_unit cannot wrap a quantity that already has a unit"}

        value_type != :decimal ->
          {:error, "add_unit function expects a number, #{got(value_type)}"}

        unit_type != :string ->
          {:error, "add_unit function expects a string unit, #{got(unit_type)}"}

        true ->
          with {:ok, canonical} <- resolve_name(unit_ast, context),
               {:ok, category} <- Catalog.category_for_unit(context.units, canonical) do
            {:ok, category}
          end
      end
    end
  end

  @impl Function
  @doc false
  def call([%Decimal{} = value, symbol], ctx \\ %Context{}) when is_binary(symbol) do
    with {:ok, canonical} <- resolve_name(symbol, ctx) do
      {:ok, %Quantity{value: value, unit: Unit.new!(canonical)}}
    end
  end

  @impl Function
  @doc false
  def documentation do
    %{
      signature: "add_unit(value, unit)",
      description: "wraps a number as a quantity of the given unit",
      category: :math
    }
  end

  defp resolve_name(symbol, %{units: %Catalog{} = catalog}) when is_binary(symbol) do
    case Catalog.canonical_name(catalog, symbol) do
      {:ok, canonical} -> {:ok, canonical}
      :error -> unregistered_symbol_error(symbol)
    end
  end

  defp resolve_name(symbol, _context) when is_binary(symbol) do
    {:error, "unknown unit '#{symbol}'"}
  end

  defp resolve_name({:var, name}, %{variables: variables} = context) when is_binary(name) do
    case Map.get(variables, name) do
      %{value: value} when is_binary(value) ->
        resolve_name(value, context)

      _ ->
        {:error, "add_unit expects a registered unit symbol literal"}
    end
  end

  defp resolve_name(_unit_ast, _context) do
    {:error, "add_unit expects a registered unit symbol literal"}
  end

  defp unregistered_symbol_error(symbol) do
    if formula?(symbol) do
      {:error, "add_unit expects a registered unit symbol, got '#{symbol}'"}
    else
      {:error, "unknown unit '#{symbol}'"}
    end
  end

  defp formula?(symbol) do
    String.contains?(symbol, ["*", "/", "(", ")", " ", "^", "|"])
  end
end
