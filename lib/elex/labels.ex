defmodule Elex.Labels do
  @moduledoc """
  Provides human-readable labels for expression types.

  Used by [`Elex.Validator`](Elex.Validator) and [`Elex.Evaluator`](Elex.Evaluator)
  when formatting type error messages.

  This module can be extended by applications to provide localized labels using Gettext.

  ## Supported types

  | Type       | Label    |
  |------------|----------|
  | `:decimal` | "number" |
  | `:string`  | "text"   |
  | `:boolean` | "yes/no" |
  | `nil`      | "empty"  |
  | `:unknown` | "value"  |
  """

  @doc """
  Returns a human-readable label for an expression type.

  Can be overridden in applications that use Gettext for localization.

  ## Parameters

  - `type` - An expression type atom (`:decimal`, `:string`, `:boolean`, or `:unknown`)

  ## Returns

  A short human-readable label string.

  ## Examples

      label(:decimal)
      #=> "number"

      label(:boolean)
      #=> "yes/no"

  """
  def label(:decimal), do: "number"
  def label(:string), do: "text"
  def label(:boolean), do: "yes/no"
  def label(nil), do: "empty"
  def label(:unknown), do: "value"
  def label(%Elex.Dimension{} = dim), do: to_string(dim)
  def label(type) when is_atom(type), do: Atom.to_string(type)

  @doc """
  Formats a `got …` clause for function type errors.

  Primitive types stay `got decimal`. Category atoms become `got length quantity`
  so `length(1m)` is not read as a tautology.

  ## Examples

      got(:decimal)
      #=> "got decimal"

      got(:length)
      #=> "got length quantity"

  """
  def got(nil), do: "got empty"
  def got(type) when type in [:decimal, :string, :boolean], do: "got #{type}"
  def got({:dim, dim}) when is_map(dim), do: got(%Elex.Dimension{monomial: dim})
  def got(%Elex.Dimension{monomial: monomial}) when map_size(monomial) == 0, do: "got number"
  def got(%Elex.Dimension{} = dim), do: "got #{dim} quantity"
  def got(type) when is_atom(type), do: "got #{type} quantity"
end
