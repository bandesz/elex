defmodule Elex.Quantity do
  @moduledoc """
  A measured value with a unit.

  Evaluate returns `%Elex.Quantity{}` for unitful results. The `:unit` is an
  `%Elex.Unit{}` monomial (`%{"N" => 1}`, `%{"m" => 2}`, `%{"m" => 1, "s" => -1}`).

  ## Fields

  - `:value` - The numeric magnitude as a `Decimal.t()`
  - `:unit` - An `%Elex.Unit{}`

  ## Examples

      %Elex.Quantity{value: Decimal.new("1.001"), unit: Elex.Unit.new!(%{"m" => 1})}
      %Elex.Quantity{value: Decimal.new("10"), unit: Elex.Unit.new!(%{"m" => 1, "s" => -1})}
  """
  defstruct [:value, :unit]

  @typedoc """
  An `Elex.Unit` carried by a quantity.
  """
  @type unit :: Elex.Unit.t()

  @typedoc """
  A quantity with a decimal magnitude and a unit.
  """
  @type t :: %__MODULE__{
          value: Decimal.t(),
          unit: unit()
        }

  defimpl Inspect do
    def inspect(%Elex.Quantity{value: value, unit: %Elex.Unit{} = unit}, _opts) do
      "#Elex.Quantity<#{format_quantity(value, unit)}>"
    end

    defp format_quantity(value, unit) do
      magnitude = value |> Decimal.normalize() |> Decimal.to_string(:normal)

      case format_unit(unit) do
        "1 | " <> rest -> magnitude <> " | " <> rest
        unit_text -> magnitude <> " " <> unit_text
      end
    end

    defp format_unit(%Elex.Unit{} = unit) do
      unit
      |> inspect()
      |> String.replace_prefix("#Elex.Unit<", "")
      |> String.replace_suffix(">", "")
    end
  end
end
