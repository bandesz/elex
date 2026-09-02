defmodule Elex.Dimension do
  @moduledoc """
  A category formula as a canonical monomial of base categories.

  Validate returns this for unitful results (base categories → exponents).
  It is never collapsed to a derived name (`:speed`, `:force`). Inspect uses
  the same formula language as units, with category atoms: `length | time`,
  `length^2`, `length | mass * time^2`.

  ## Fields

  - `:monomial` - A map of base category atoms to integer exponents

  ## Examples

      %Elex.Dimension{monomial: %{length: 1}}
      %Elex.Dimension{monomial: %{length: 1, time: -1}}
  """
  defstruct [:monomial]

  @typedoc """
  A monomial of base category atoms to integer exponents.
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
