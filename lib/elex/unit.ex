defmodule Elex.Unit do
  @moduledoc """
  A unit of measure as a canonical monomial and a denominator coefficient.

  Evaluate returns a unit with a monomial and a denominator coefficient
  (`per`, default `1`). Zero exponents are dropped. Names
  are not split on trailing digits (`m2` stays `%{"m2" => 1}`). Inspect
  always formats the monomial with `|` and `^` (`m^2`, `m | s`, `m | s^2`).
  A single exponent-1 symbol prints as that symbol (`N`, `mm`). A coefficient
  greater than 1 prints after `|` (`L | 100 km`, `1 | 100 s`).

  `same?/2` compares monomials and `per`. `convertible?/3` takes a catalog and
  is true when both units have the same dimension vector (`m` and `km` of
  `:length`), ignoring `per`. `compatible?/3` maps a unit monomial to a
  category formula and compares it to a category (`cm | s` vs `:speed`), also
  ignoring `per`.

  ## Fields

  - `:monomial` - A map of symbols to integer exponents
  - `:per` - A positive integer denominator coefficient, default `1`

  ## Examples

      %Elex.Unit{monomial: %{"m" => 1}}
      %Elex.Unit{monomial: %{"m" => 1, "s" => -1}}
      %Elex.Unit{monomial: %{"L" => 1, "km" => -1}, per: 100}
  """
  defstruct monomial: nil, per: 1

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
          monomial: monomial(),
          per: pos_integer()
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
      {:ok, monomial, per} -> new_with_per(monomial, per)
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
    left.monomial == right.monomial and left.per == right.per
  end

  @doc """
  Returns true when both units have the same dimension vector in `catalog`.

  A pure power of a derived category (`%{volume => n}`) matches that
  category's stored dimension scaled by `n`. A mixed vector is compared as
  stored. Unknown symbols are not convertible.
  """
  @spec convertible?(t(), t(), Catalog.t()) :: boolean()
  def convertible?(%__MODULE__{} = left, %__MODULE__{} = right, %Catalog{} = catalog) do
    case {Catalog.unit_dim(catalog, left), Catalog.unit_dim(catalog, right)} do
      {{:ok, left_dim}, {:ok, right_dim}} ->
        reduce_nominal_power(catalog, left_dim) == reduce_nominal_power(catalog, right_dim)

      _ ->
        false
    end
  end

  @doc """
  Returns true when `unit`'s category formula matches `category` in `catalog`.

  Each symbol in the unit monomial is mapped to its category and exponents
  are combined. The result is compared to the category's formula (or dim).
  A pure power of a derived category matches that category's stored dimension
  scaled by the same exponent. `cm | s` is compatible with `:speed` even if
  `cm/s` is not a registered unit.
  """
  @spec compatible?(t(), atom(), Catalog.t()) :: boolean()
  def compatible?(%__MODULE__{} = unit, category, %Catalog{} = catalog) when is_atom(category) do
    case {Catalog.unit_dim(catalog, unit), Catalog.dimension(catalog, category)} do
      {{:ok, dim}, {:ok, %Elex.Dimension{monomial: category_dim}}} ->
        reduce_nominal_power(catalog, dim) == reduce_nominal_power(catalog, category_dim)

      _ ->
        false
    end
  end

  @doc false
  @spec reduce_nominal_power(Catalog.t(), %{optional(atom()) => integer()}) ::
          %{optional(atom()) => integer()}
  def reduce_nominal_power(%Catalog{} = catalog, dim) when is_map(dim) do
    case Map.to_list(dim) do
      [{category, exponent}] ->
        reduce_derived_power(catalog, category, exponent, dim)

      _ ->
        dim
    end
  end

  defp reduce_derived_power(catalog, category, exponent, dim) do
    case Catalog.kind(catalog, category) do
      {:ok, :derived} ->
        {:ok, %Elex.Dimension{monomial: stored}} = Catalog.dimension(catalog, category)
        scale_exponents(stored, exponent)

      _ ->
        dim
    end
  end

  defp scale_exponents(dim, exponent) do
    dim
    |> Map.new(fn {category, n} -> {category, n * exponent} end)
    |> Enum.reject(fn {_category, n} -> n == 0 end)
    |> Map.new()
  end

  defp new_with_per(monomial, per) do
    with {:ok, unit} <- new(monomial) do
      {:ok, %{unit | per: per}}
    end
  end

  defp canonicalize(monomial) do
    monomial
    |> Enum.reject(fn {_name, exponent} -> exponent == 0 end)
    |> Map.new()
  end

  defimpl Inspect do
    def inspect(%Elex.Unit{monomial: monomial, per: per}, _opts) do
      "#Elex.Unit<#{format_monomial(monomial, per)}>"
    end

    defp format_monomial(monomial, per) do
      {numerators, denominators} =
        monomial
        |> Enum.sort_by(fn {symbol, _exponent} -> symbol end)
        |> Enum.split_with(fn {_symbol, exponent} -> exponent > 0 end)

      num_formula = Enum.map_join(numerators, " * ", &format_factor/1)
      den_formula = format_denominator(denominators, per)

      cond do
        denominators == [] ->
          num_formula

        numerators == [] ->
          "1 | " <> den_formula

        true ->
          num_formula <> " | " <> den_formula
      end
    end

    defp format_denominator(denominators, per) when per > 1 do
      "#{per} " <> Enum.map_join(denominators, " * ", &format_factor/1)
    end

    defp format_denominator(denominators, _per) do
      Enum.map_join(denominators, " * ", &format_factor/1)
    end

    defp format_factor({symbol, exponent}) when abs(exponent) == 1, do: symbol
    defp format_factor({symbol, exponent}), do: "#{symbol}^#{abs(exponent)}"
  end
end
