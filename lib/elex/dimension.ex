defmodule Elex.Dimension do
  @moduledoc """
  A category formula as a canonical monomial of category atoms.

  Validate returns this for unitful results (category atoms → exponents).
  All-base formulas store base category atoms (`length | time`, `length^2`,
  `length | mass * time^2`). A formula that names a derived category stores
  that atom (`volume | length`). Inspect uses the same formula language as
  units.

  ## Fields

  - `:monomial` - A map of category atoms to integer exponents. A key may
    name a base category or a derived category.

  ## Examples

      %Elex.Dimension{monomial: %{length: 1}}
      %Elex.Dimension{monomial: %{length: 1, time: -1}}
      %Elex.Dimension{monomial: %{volume: 1, length: -1}}
  """
  defstruct [:monomial]

  @typedoc """
  A monomial of category atoms to integer exponents.
  A key may name a base category or a derived category.
  """
  @type monomial :: %{optional(atom()) => integer()}

  @typedoc """
  A category formula as a canonical monomial.
  """
  @type t :: %__MODULE__{
          monomial: monomial()
        }

  @doc """
  Formats the category formula (`length | time`, `length^2`).

  An empty monomial is `number`.
  """
  @spec formula(t()) :: String.t()
  def formula(%__MODULE__{monomial: monomial}) do
    {numerators, denominators} =
      monomial
      |> Enum.sort_by(fn {category, _exponent} -> category end)
      |> Enum.split_with(fn {_category, exponent} -> exponent > 0 end)

    num_formula = Enum.map_join(numerators, " * ", &format_factor/1)
    den_formula = Enum.map_join(denominators, " * ", &format_factor/1)

    cond do
      numerators == [] and denominators == [] ->
        "number"

      denominators == [] ->
        num_formula

      numerators == [] ->
        "1 | " <> den_formula

      true ->
        num_formula <> " | " <> den_formula
    end
  end

  defp format_factor({category, exponent}) when abs(exponent) == 1, do: Atom.to_string(category)
  defp format_factor({category, exponent}), do: "#{category}^#{abs(exponent)}"

  defimpl Inspect do
    def inspect(%Elex.Dimension{} = dim, _opts) do
      "#Elex.Dimension<#{Elex.Dimension.formula(dim)}>"
    end
  end

  defimpl String.Chars do
    def to_string(%Elex.Dimension{} = dim), do: Elex.Dimension.formula(dim)
  end
end
