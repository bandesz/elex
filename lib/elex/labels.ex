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
end
