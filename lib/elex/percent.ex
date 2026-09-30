defmodule Elex.Percent do
  @moduledoc """
  A percent stored as percent points.

  `50%` is `%Elex.Percent{value: Decimal.new("50")}`. Callers build the struct
  directly.

  ## Fields

  - `:value` - The percent points as a `Decimal.t()`

  ## Examples

      %Elex.Percent{value: Decimal.new("50")}
      %Elex.Percent{value: Decimal.new("-10")}
  """
  defstruct [:value]

  @typedoc """
  A percent with decimal percent points.
  """
  @type t :: %__MODULE__{
          value: Decimal.t()
        }

  defimpl Inspect do
    def inspect(%Elex.Percent{value: value}, _opts) do
      points = value |> Decimal.normalize() |> Decimal.to_string(:normal)
      "#Elex.Percent<#{points}%>"
    end
  end
end
