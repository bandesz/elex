defmodule Elex.Unit do
  @moduledoc """
  A unit of measure as a canonical monomial.

  Evaluate returns a unit monomial only. Zero exponents are dropped. Names
  are not split on trailing digits (`m2` stays `%{"m2" => 1}`). Inspect
  always formats the monomial with `|` and `^` (`m^2`, `m | s`, `m | s^2`).
  A single exponent-1 symbol prints as that symbol (`N`, `mm`).

  `same?/2` compares monomials. `convertible?/3` takes a catalog and is true
  when both units have the same dimension vector (`m` and `km` of `:length`).
  `compatible?/3` maps a unit monomial to a category formula and compares it
  to a category (`cm | s` vs `:speed`).

  ## Fields

  - `:monomial` - A map of symbols to integer exponents

  ## Examples

      %Elex.Unit{monomial: %{"m" => 1}}
      %Elex.Unit{monomial: %{"m" => 1, "s" => -1}}
  """
  defstruct [:monomial]

  alias Elex.Units.Catalog
  alias Elex.Units.Formula

  @typedoc """
  A monomial of unit symbols to integer exponents.
  """
  @type monomial :: %{optional(String.t()) => integer()}

  @typedoc """
  A unit as a canonical monomial.
  """
  @type t :: %__MODULE__{
          monomial: monomial()
        }

  @doc """
  Builds a unit from a formula string or monomial map.

  An empty monomial (`%{}` or only zero exponents) is an error.

  ## Returns

  - `{:ok, unit}` - A parsed unit
  - `{:error, String.t()}` - The formula could not be parsed
  """
  @spec new(String.t() | monomial()) :: {:ok, t()} | {:error, String.t()}
  def new(source) when is_binary(source) do
    case Formula.parse(source) do
      {:ok, monomial} -> new(monomial)
      {:error, reason} -> {:error, reason}
    end
  end

  def new(monomial) when is_map(monomial) do
    case from_monomial(monomial) do
      nil -> {:error, "empty unit"}
      unit -> {:ok, unit}
    end
  end

  @doc """
  Same as `new/1`, but returns the unit or raises `ArgumentError`.
  """
  @spec new!(String.t() | monomial()) :: t()
  def new!(source) do
    case new(source) do
      {:ok, unit} -> unit
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Builds a unit from a monomial.

  An empty monomial is invalid (`nil`).
  """
  @spec from_monomial(monomial()) :: t() | nil
  def from_monomial(monomial) when is_map(monomial) do
    monomial = canonicalize(monomial)

    case map_size(monomial) do
      0 -> nil
      _ -> %__MODULE__{monomial: monomial}
    end
  end

  @spec same?(t(), t()) :: boolean()
  def same?(%__MODULE__{} = left, %__MODULE__{} = right) do
    left.monomial == right.monomial
  end

  @doc """
  Returns true when both units have the same dimension vector in `catalog`.

  Unknown symbols are not convertible.
  """
  @spec convertible?(t(), t(), Catalog.t()) :: boolean()
  def convertible?(%__MODULE__{} = left, %__MODULE__{} = right, %Catalog{} = catalog) do
    case {Catalog.unit_dim(catalog, left), Catalog.unit_dim(catalog, right)} do
      {{:ok, dim}, {:ok, dim}} -> true
      _ -> false
    end
  end

  @doc """
  Returns true when `unit`'s category formula matches `category` in `catalog`.

  Each symbol in the unit monomial is mapped to its category and exponents
  are combined. The result is compared to the category's formula (or dim).
  `cm | s` is compatible with `:speed` even if `cm/s` is not a registered unit.
  """
  @spec compatible?(t(), atom(), Catalog.t()) :: boolean()
  def compatible?(%__MODULE__{} = unit, category, %Catalog{} = catalog) when is_atom(category) do
    case {Catalog.unit_dim(catalog, unit), Catalog.dimension(catalog, category)} do
      {{:ok, dim}, {:ok, %Elex.Dimension{monomial: dim}}} -> true
      _ -> false
    end
  end

  defp canonicalize(monomial) do
    monomial
    |> Enum.reject(fn {_name, exponent} -> exponent == 0 end)
    |> Map.new()
  end

  defimpl Inspect do
    def inspect(%Elex.Unit{monomial: monomial}, _opts) do
      "#Elex.Unit<#{format_monomial(monomial)}>"
    end

    defp format_monomial(monomial) do
      {numerators, denominators} =
        monomial
        |> Enum.sort_by(fn {symbol, _exponent} -> symbol end)
        |> Enum.split_with(fn {_symbol, exponent} -> exponent > 0 end)

      num_formula = Enum.map_join(numerators, " * ", &format_factor/1)
      den_formula = Enum.map_join(denominators, " * ", &format_factor/1)

      cond do
        denominators == [] ->
          num_formula

        numerators == [] ->
          "1 | " <> den_formula

        true ->
          num_formula <> " | " <> den_formula
      end
    end

    defp format_factor({symbol, exponent}) when abs(exponent) == 1, do: symbol
    defp format_factor({symbol, exponent}), do: "#{symbol}^#{abs(exponent)}"
  end
end
