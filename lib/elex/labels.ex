defmodule Elex.Labels do
  @moduledoc """
  Provides human-readable labels for expression types.

  This module can be extended by applications to provide localized labels using Gettext.
  """

  @doc """
  Returns a human-readable label for an expression type.

  Can be overridden in applications that use Gettext for localization.
  """
  def label(:decimal), do: "number"
  def label(:string), do: "text"
  def label(:boolean), do: "yes/no"
end
