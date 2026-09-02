defmodule Elex.Units.Catalog do
  @moduledoc """
  Caller-registered unit categories.

  Elex does not ship units. A catalog is what the caller registers with
  `add_category/3` and `add_unit/3` (optional conversion and `aliases:`).
  Omitting conversion registers `"value"`. Optional `aliases:` are extra
  input spellings of a canonical unit. They must be symbol-pattern names,
  unique catalog-wide, and are not valid as `default:`:

      Catalog.add_unit(catalog, :area, "m^2", aliases: ["m2", "sqm"])

  Derived `add_category` may take `identity:` (a unit formula of the
  base-hub product) so a named hub such as `"N"` can name that formula.
  A matching identity unit must still be registered. `identity:` is
  rejected on base categories.

  `add_unit/4` takes an explicit conversion string; `aliases:` defaults
  to `[]`. The conversion must be a string (`value / 100`), not a charlist.
  A formula-shaped unit name whose components are already registered
  must use a matching scale (`cm` at `value / 100` means `"cm^2"` is
  `value / 10000`). `identity:` names the base-hub formula; a matching
  unit must still be registered (`N` plus `"kg * m | s^2"`, `ha` plus
  `"m^2"`). `add_category!/3` and `add_unit!/3` raise `ArgumentError`
  instead of returning `{:error, reason}`.
  """

  alias Elex.Inverter
  alias Elex.Parser
  alias Elex.Units.Formula

  defstruct categories: %{}

  @reserved_words ~w(and or not null true false yes no e E)
  @unit_name_pattern ~r/^[A-Za-z][A-Za-z0-9_]*$/

  @type t :: %__MODULE__{
          categories: %{optional(atom()) => category()}
        }

  @type unit :: %{
          required(:to_default) => String.t(),
          required(:to_default_ast) => term(),
          required(:from_default_ast) => term(),
          optional(:aliases) => [String.t()]
        }

  @type category :: %{
          required(:default) => String.t(),
          required(:additive) => boolean(),
          required(:units) => %{optional(String.t()) => unit()},
          optional(:formula) => String.t(),
          optional(:dim) => %{optional(atom()) => integer()},
          optional(:identity) => String.t()
        }

  @doc """
  Returns an empty catalog.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Registers a base or derived category.

  Base and derived categories take `default:` — the conversion-hub unit
  (must be registered on that category before `put_units/2`). Derived
  categories also take `formula:` over base category names, and optional
  `identity:` — a unit formula of the base-hub product. A matching identity
  unit must still be registered before `put_units/2`. `identity:` is
  rejected on base categories. `default_result_unit:` is rejected; use
  `default:`. `additive:` defaults to `true`; offset conversions require
  `additive: false`.

  ## Returns

  - `{:ok, catalog}` - Updated catalog
  - `{:error, String.t()}` - Registration failed
  """
  @spec add_category(t(), atom(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def add_category(%__MODULE__{} = catalog, name, opts) when is_atom(name) do
    cond do
      Keyword.has_key?(opts, :default_result_unit) ->
        {:error, "use default: instead of default_result_unit:"}

      Map.has_key?(catalog.categories, name) ->
        {:error, "category :#{name} already exists"}

      Keyword.has_key?(opts, :formula) ->
        add_derived_category(catalog, name, opts)

      true ->
        add_base_category(catalog, name, opts)
    end
  end

  @doc """
  Same as `add_category/3`, but returns the catalog or raises `ArgumentError`.
  """
  @spec add_category!(t(), atom(), keyword()) :: t()
  def add_category!(%__MODULE__{} = catalog, name, opts) when is_atom(name) do
    case add_category(catalog, name, opts) do
      {:ok, catalog} -> catalog
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Returns a map of registered category names to their conversion-default unit symbols.
  """
  @spec categories(t()) :: %{optional(atom()) => String.t()}
  def categories(%__MODULE__{} = catalog) do
    Map.new(catalog.categories, fn {name, category} ->
      {name, Map.get(category, :default)}
    end)
  end

  @doc """
  Looks up the category atom for a registered unit symbol or alias.

  ## Returns

  - `{:ok, category}` - The category the unit belongs to
  - `:error` - The symbol is not registered
  """
  @spec category_for_unit(t(), String.t()) :: {:ok, atom()} | :error
  def category_for_unit(%__MODULE__{} = catalog, name) when is_binary(name) do
    Enum.find_value(catalog.categories, :error, fn {category, %{units: units}} ->
      if unit_or_alias?(units, name), do: {:ok, category}
    end)
  end

  @doc """
  Looks up the category whose dimension vector matches `dim`.

  Base categories match `%{category => 1}`. Derived categories match
  the stored `:dim` from their formula.
  """
  @spec category_for_dim(t(), %{optional(atom()) => integer()}) :: {:ok, atom()} | :error
  def category_for_dim(%__MODULE__{} = catalog, dim) when is_map(dim) do
    Enum.find_value(catalog.categories, :error, fn {name, entry} ->
      if Map.get(entry, :dim, %{name => 1}) == dim, do: {:ok, name}
    end)
  end

  @doc """
  Looks up a registered unit entry by canonical name or alias.

  ## Returns

  - `{:ok, unit}` - The unit with conversion ASTs
  - `:error` - The name is not a registered unit or alias
  """
  @spec fetch_unit(t(), String.t()) :: {:ok, unit()} | :error
  def fetch_unit(%__MODULE__{} = catalog, name) when is_binary(name) do
    with {:ok, canonical} <- canonical_name(catalog, name) do
      fetch_canonical_unit(catalog, canonical)
    end
  end

  @doc """
  Parses a unit formula against this catalog.

  Rejects an invalid formula, unknown symbols, a formula that places
  the same category in both the numerator and the denominator (after
  expanding derived units), and a formula that cancels to an empty unit.
  """
  @spec parse_formula(t(), String.t()) :: {:ok, Formula.monomial()} | {:error, String.t()}
  def parse_formula(%__MODULE__{} = catalog, source) when is_binary(source) do
    with {:ok, monomial} <- Formula.parse(source),
         monomial <- expand_alias_monomial(catalog, monomial),
         :ok <- reject_unknown_formula_symbols(catalog, monomial),
         :ok <- reject_formula_repeated_category(catalog, source),
         :ok <- reject_empty_formula_dimension(catalog, monomial, source) do
      {:ok, monomial}
    end
  end

  @doc """
  Resolves a registered unit name or alias to the canonical unit name.
  """
  @spec canonical_name(t(), String.t()) :: {:ok, String.t()} | :error
  def canonical_name(%__MODULE__{} = catalog, name) when is_binary(name) do
    Enum.find_value(catalog.categories, :error, fn {_category, %{units: units}} ->
      canonical_name_in_units(units, name)
    end)
  end

  @doc false
  @spec additive?(t(), atom()) :: boolean()
  def additive?(%__MODULE__{} = catalog, category) when is_atom(category) do
    case Map.fetch(catalog.categories, category) do
      {:ok, entry} -> Map.get(entry, :additive, true)
      :error -> true
    end
  end

  @doc false
  @spec unit_dim(t(), Elex.Unit.t() | %{optional(String.t()) => integer()}) ::
          {:ok, %{optional(atom()) => integer()}} | {:error, String.t()}
  def unit_dim(%__MODULE__{} = catalog, %Elex.Unit{monomial: monomial}) do
    unit_dim(catalog, monomial)
  end

  def unit_dim(%__MODULE__{} = catalog, monomial) when is_map(monomial) do
    Enum.reduce_while(monomial, {:ok, %{}}, fn {symbol, exponent}, {:ok, acc} ->
      case lookup_symbol_dim(catalog, symbol) do
        {:ok, dim} ->
          {:cont, {:ok, combine_dim(acc, scale_dim(dim, exponent))}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Looks up a category's formula as a dimension.

  Base categories are `%{category => 1}`. Derived categories use the stored
  `:dim` from their formula.
  """
  @spec dimension(t(), atom()) :: {:ok, Elex.Dimension.t()} | :error
  def dimension(%__MODULE__{} = catalog, category) when is_atom(category) do
    case Map.fetch(catalog.categories, category) do
      {:ok, entry} ->
        {:ok, %Elex.Dimension{monomial: Map.get(entry, :dim, %{category => 1})}}

      :error ->
        :error
    end
  end

  @doc """
  Returns whether `name` is a base or derived category.

  ## Returns

  - `{:ok, :base}` - The category has no `formula:`
  - `{:ok, :derived}` - The category was registered with `formula:`
  - `:error` - The name is not a registered category
  """
  @spec kind(t(), atom()) :: {:ok, :base} | {:ok, :derived} | :error
  def kind(%__MODULE__{} = catalog, name) when is_atom(name) do
    case Map.fetch(catalog.categories, name) do
      {:ok, entry} ->
        if Map.has_key?(entry, :formula), do: {:ok, :derived}, else: {:ok, :base}

      :error ->
        :error
    end
  end

  @doc false
  @spec formula_identity(t(), atom()) :: {String.t(), Formula.monomial()} | nil
  def formula_identity(%__MODULE__{} = catalog, category) when is_atom(category) do
    case Map.fetch(catalog.categories, category) do
      {:ok, entry} -> formula_identity_for_entry(catalog, entry)
      :error -> nil
    end
  end

  defp affine_conversion?(ast) do
    ctx = Elex.new_context() |> Elex.add_variable!("value", Decimal.new(0))
    offset = Elex.Evaluator.evaluate!(ast, ctx)
    Decimal.compare(offset, Decimal.new(0)) != :eq
  end

  @doc """
  Returns `:ok` when every category `default:` hub is registered on that
  category and every derived category has a base-hub identity (`default:`
  name parses to the identity monomial, or a matching unit name).
  `identity:` does not substitute for that unit.
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = catalog) do
    Enum.reduce_while(catalog.categories, :ok, fn {name, entry}, :ok ->
      case validate_category(catalog, name, entry) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp validate_category(catalog, name, entry) do
    with :ok <- validate_default_hub(name, entry) do
      validate_derived_identity(catalog, name, entry)
    end
  end

  defp validate_default_hub(name, entry) do
    default = Map.get(entry, :default)

    if is_binary(default) and not Map.has_key?(entry.units, default) do
      {:error, "default '#{default}' is not among the units of :#{name}"}
    else
      :ok
    end
  end

  defp validate_derived_identity(_catalog, _name, entry) when not is_map_key(entry, :formula) do
    :ok
  end

  defp validate_derived_identity(catalog, name, entry) do
    identity = identity_monomial(catalog, entry)

    if derived_identity?(entry, identity) do
      :ok
    else
      example = format_identity_example(identity)

      {:error,
       "derived category :#{name} needs a registered unit matching the base hubs (e.g. \"#{example}\")"}
    end
  end

  defp derived_identity?(entry, identity) do
    parses_to_identity?(entry.default, identity) or
      identity_unit?(entry.units, identity)
  end

  defp parses_to_identity?(name, identity) do
    case Formula.parse(name) do
      {:ok, ^identity} -> true
      _ -> false
    end
  end

  defp identity_monomial(catalog, entry) do
    {:ok, monomial} = Formula.parse(entry.formula)

    Enum.reduce(monomial, %{}, fn {component, exponent}, acc ->
      {:ok, category} = fetch_base_category(catalog, component)
      hub = catalog.categories[category].default
      Map.update(acc, hub, exponent, &(&1 + exponent))
    end)
    |> drop_zero_exponents()
  end

  defp identity_unit?(units, identity) do
    match_identity_unit(units, identity) != nil
  end

  defp formula_identity_for_entry(_catalog, entry) when not is_map_key(entry, :formula), do: nil

  defp formula_identity_for_entry(catalog, entry) do
    identity = identity_monomial(catalog, entry)

    case Map.fetch(entry, :identity) do
      {:ok, formula} -> match_identity_unit(entry.units, identity) || {formula, identity}
      :error -> match_identity_unit(entry.units, identity)
    end
  end

  defp match_identity_unit(units, identity) do
    Enum.find_value(units, fn {name, _unit} ->
      case Formula.parse(name) do
        {:ok, ^identity} -> {name, identity}
        _ -> nil
      end
    end)
  end

  defp format_identity_example(monomial) do
    {numerators, denominators} =
      monomial
      |> Enum.sort_by(fn {symbol, _exponent} -> symbol end)
      |> Enum.split_with(fn {_symbol, exponent} -> exponent > 0 end)

    num_formula = format_expanded_factors(numerators)
    den_formula = format_expanded_factors(denominators)

    cond do
      denominators == [] -> num_formula
      numerators == [] -> "1 | " <> den_formula
      true -> num_formula <> " | " <> den_formula
    end
  end

  defp format_expanded_factors(factors) do
    factors
    |> Enum.flat_map(fn {symbol, exponent} -> List.duplicate(symbol, abs(exponent)) end)
    |> Enum.join(" * ")
  end

  @doc """
  Registers a unit with an invertible conversion to the category's conversion-default.

  The conversion is an Elex expression in `value` (a string, not a charlist).
  Omitting it (or passing only `aliases:`) registers `"value"`. The inverse
  is derived with `Elex.Inverter`.
  A formula unit may not place the same category in both the numerator and the
  denominator (`N * s | s`, `N * s | hour`). A formula-shaped name whose
  components are already registered must match their combined scale.

  `aliases:` are optional input-only symbol names for this canonical unit.
  They must match `^[A-Za-z][A-Za-z0-9_]*$` and be unique catalog-wide
  against unit names and other aliases. `default:` must be a canonical
  unit name, not an alias.
  """
  @spec add_unit(t(), atom(), String.t()) :: {:ok, t()} | {:error, String.t()}
  @spec add_unit(t(), atom(), String.t(), String.t() | keyword()) ::
          {:ok, t()} | {:error, String.t()}
  @spec add_unit(t(), atom(), String.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def add_unit(catalog, category, name, to_default \\ "value", opts \\ [])

  def add_unit(%__MODULE__{} = catalog, category, name, opts, [])
      when is_atom(category) and is_binary(name) and is_list(opts) do
    if Keyword.keyword?(opts) do
      add_unit(catalog, category, name, "value", opts)
    else
      {:error, "conversion must be a string"}
    end
  end

  def add_unit(%__MODULE__{} = catalog, category, name, to_default, opts)
      when is_atom(category) and is_binary(name) and is_binary(to_default) do
    aliases = Keyword.get(opts, :aliases, [])

    case Map.fetch(catalog.categories, category) do
      :error ->
        {:error, "unknown category :#{category}"}

      {:ok, category_entry} ->
        with :ok <- validate_unit_name(name, category_entry),
             :ok <- reject_duplicate_name(catalog, name),
             :ok <- validate_aliases(catalog, name, aliases),
             :ok <- reject_repeated_category(catalog, name),
             :ok <- validate_formula_dimension(catalog, category_entry, name),
             {:ok, ast, inverse} <- parse_conversion(to_default),
             :ok <- reject_offset_on_additive(category, category_entry, name, ast),
             :ok <- reject_component_scale_mismatch(catalog, category_entry, name, ast) do
          unit = unit_entry(to_default, ast, inverse, aliases)
          units = Map.put(category_entry.units, name, unit)
          categories = Map.put(catalog.categories, category, %{category_entry | units: units})
          {:ok, %{catalog | categories: categories}}
        end
    end
  end

  @doc """
  Same as `add_unit/3` (optional conversion and `aliases:`), but returns the catalog
  or raises `ArgumentError`.
  """
  @spec add_unit!(t(), atom(), String.t()) :: t()
  @spec add_unit!(t(), atom(), String.t(), String.t() | keyword()) :: t()
  @spec add_unit!(t(), atom(), String.t(), String.t(), keyword()) :: t()
  def add_unit!(catalog, category, name, to_default \\ "value", opts \\ [])

  def add_unit!(%__MODULE__{} = catalog, category, name, opts, [])
      when is_atom(category) and is_binary(name) and is_list(opts) do
    if Keyword.keyword?(opts) do
      case add_unit(catalog, category, name, "value", opts) do
        {:ok, catalog} -> catalog
        {:error, reason} -> raise ArgumentError, reason
      end
    else
      raise ArgumentError, "conversion must be a string"
    end
  end

  def add_unit!(%__MODULE__{} = catalog, category, name, to_default, opts)
      when is_atom(category) and is_binary(name) and is_binary(to_default) do
    case add_unit(catalog, category, name, to_default, opts) do
      {:ok, catalog} -> catalog
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  defp validate_unit_name(name, category_entry) do
    cond do
      name in @reserved_words ->
        {:error, "unit '#{name}' is a reserved keyword"}

      Regex.match?(@unit_name_pattern, name) ->
        :ok

      Map.has_key?(category_entry, :formula) ->
        :ok

      true ->
        {:error, "invalid unit name '#{name}'"}
    end
  end

  defp add_base_category(catalog, name, opts) do
    if Keyword.has_key?(opts, :identity) do
      {:error, "identity: is not allowed on base category :#{name}"}
    else
      case Keyword.fetch(opts, :default) do
        :error ->
          {:error, "base category :#{name} requires default:"}

        {:ok, default} ->
          with :ok <- reject_duplicate_dim(catalog, name, %{name => 1}) do
            category = %{
              default: default,
              additive: additive?(opts),
              units: %{}
            }

            {:ok, %{catalog | categories: Map.put(catalog.categories, name, category)}}
          end
      end
    end
  end

  defp add_derived_category(catalog, name, opts) do
    formula = Keyword.fetch!(opts, :formula)

    case Keyword.fetch(opts, :default) do
      :error ->
        {:error, "derived category :#{name} requires default:"}

      {:ok, default} ->
        with {:ok, monomial} <- Formula.parse(formula),
             {:ok, dim} <- category_formula_dim(catalog, monomial),
             :ok <- reject_duplicate_dim(catalog, name, dim),
             {:ok, identity} <- fetch_derived_identity(catalog, name, opts, formula) do
          category =
            %{
              formula: formula,
              dim: dim,
              default: default,
              additive: additive?(opts),
              units: %{}
            }
            |> maybe_put_identity(identity)

          {:ok, %{catalog | categories: Map.put(catalog.categories, name, category)}}
        end
    end
  end

  defp fetch_derived_identity(catalog, name, opts, formula) do
    case Keyword.fetch(opts, :identity) do
      :error ->
        {:ok, nil}

      {:ok, identity} ->
        expected = identity_monomial(catalog, %{formula: formula})

        case Formula.parse(identity) do
          {:ok, ^expected} ->
            {:ok, identity}

          {:ok, _other} ->
            {:error, "identity '#{identity}' does not match the base-hub product of :#{name}"}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp maybe_put_identity(category, nil), do: category
  defp maybe_put_identity(category, identity), do: Map.put(category, :identity, identity)

  defp additive?(opts), do: Keyword.get(opts, :additive, true)

  defp reject_offset_on_additive(category, category_entry, name, ast) do
    if Map.get(category_entry, :additive, true) and affine_conversion?(ast) do
      {:error, "offset conversion for '#{name}' is not allowed on additive category :#{category}"}
    else
      :ok
    end
  end

  defp reject_component_scale_mismatch(catalog, category_entry, name, ast) do
    case component_scale_monomial(name) do
      :skip ->
        :ok

      monomial ->
        compare_component_scale(catalog, category_entry, name, monomial, ast)
    end
  end

  defp component_scale_monomial(name) do
    case Formula.parse(name) do
      {:ok, monomial} ->
        if monomial == %{name => 1}, do: :skip, else: monomial

      {:error, _} ->
        :skip
    end
  end

  defp compare_component_scale(catalog, category_entry, name, monomial, ast) do
    if affine_conversion?(ast) do
      :ok
    else
      compare_expanded_component_scale(catalog, category_entry, name, monomial, ast)
    end
  end

  defp compare_expanded_component_scale(catalog, category_entry, name, monomial, ast) do
    case component_default_monomial(catalog, monomial) do
      {:ok, expanded} ->
        compare_if_same_default(expanded, catalog, category_entry, name, monomial, ast)

      :skip ->
        :ok
    end
  end

  defp compare_if_same_default(expanded, catalog, category_entry, name, monomial, ast) do
    if expanded == default_unit_monomial(category_entry.default) do
      compare_matching_component_scale(catalog, name, monomial, ast)
    else
      :ok
    end
  end

  defp compare_matching_component_scale(catalog, name, monomial, ast) do
    case {component_to_default_factor(catalog, monomial), conversion_at_one(ast)} do
      {:skip, _} ->
        :ok

      {{:ok, expected}, {:ok, actual}} ->
        matching_component_scale_result(name, expected, actual)
    end
  end

  defp matching_component_scale_result(name, expected, actual) do
    if Decimal.compare(expected, actual) == :eq do
      :ok
    else
      {:error, "unit '#{name}' conversion does not match the scale of its component units"}
    end
  end

  defp component_default_monomial(catalog, monomial) do
    Enum.reduce_while(monomial, {:ok, %{}}, fn {symbol, exponent}, {:ok, acc} ->
      case category_for_unit(catalog, symbol) do
        :error ->
          {:halt, :skip}

        {:ok, category} ->
          default = categories(catalog)[category]
          {:cont, {:ok, combine_dim(acc, scale_dim(default_unit_monomial(default), exponent))}}
      end
    end)
  end

  defp default_unit_monomial(default) when is_binary(default) do
    case Formula.parse(default) do
      {:ok, monomial} -> monomial
      {:error, _} -> %{default => 1}
    end
  end

  defp component_to_default_factor(catalog, monomial) do
    Enum.reduce_while(monomial, {:ok, Decimal.new(1)}, fn {symbol, exponent}, {:ok, acc} ->
      case fetch_unit(catalog, symbol) do
        :error -> {:halt, :skip}
        {:ok, unit} -> scale_component_factor(unit, exponent, acc)
      end
    end)
  end

  defp scale_component_factor(unit, exponent, acc) do
    if affine_conversion?(unit.to_default_ast) do
      {:halt, :skip}
    else
      factor = conversion_at_one!(unit.to_default_ast)
      {:cont, {:ok, Decimal.mult(acc, integer_pow(factor, exponent))}}
    end
  end

  defp conversion_at_one(ast) do
    {:ok, conversion_at_one!(ast)}
  end

  defp conversion_at_one!(ast) do
    ctx = Elex.new_context() |> Elex.add_variable!("value", Decimal.new(1))
    Elex.Evaluator.evaluate!(ast, ctx)
  end

  defp integer_pow(_base, 0), do: Decimal.new(1)
  defp integer_pow(base, 1), do: base

  defp integer_pow(base, exponent) when exponent > 1 do
    Enum.reduce(2..exponent, base, fn _, acc -> Decimal.mult(acc, base) end)
  end

  defp integer_pow(base, exponent) when exponent < 0 do
    Decimal.div(Decimal.new(1), integer_pow(base, -exponent))
  end

  defp category_formula_dim(catalog, monomial) do
    Enum.reduce_while(monomial, {:ok, %{}}, fn {name, exponent}, {:ok, acc} ->
      case fetch_base_category(catalog, name) do
        {:ok, category} ->
          {:cont, {:ok, combine_dim(acc, %{category => exponent})}}

        {:error, :derived, category} ->
          {:halt, {:error, "formula may only use base categories; :#{category} is derived"}}

        :error ->
          {:halt, {:error, "unknown category :#{name}"}}
      end
    end)
  end

  defp fetch_base_category(catalog, name) do
    Enum.find_value(catalog.categories, :error, fn {category, entry} ->
      fetch_named_base_category(category, entry, name)
    end)
  end

  defp fetch_named_base_category(category, entry, name) do
    cond do
      Atom.to_string(category) != name ->
        nil

      Map.has_key?(entry, :formula) ->
        {:error, :derived, category}

      true ->
        {:ok, category}
    end
  end

  defp validate_formula_dimension(catalog, category_entry, name) when is_binary(name) do
    if Regex.match?(@unit_name_pattern, name) do
      :ok
    else
      validate_derived_formula_dimension(catalog, category_entry, name)
    end
  end

  defp validate_derived_formula_dimension(catalog, category_entry, name) do
    with {:ok, dim} <- formula_unit_dim(catalog, name) do
      if dim == category_entry.dim do
        :ok
      else
        {:error, "formula '#{name}' does not match the category dimension"}
      end
    end
  end

  defp formula_unit_dim(catalog, name) do
    with {:ok, monomial} <- Formula.parse(name) do
      unit_dim(catalog, monomial)
    end
  end

  defp lookup_symbol_dim(catalog, symbol) do
    case category_for_unit(catalog, symbol) do
      {:ok, category} ->
        {:ok, category_dim(catalog, category)}

      :error ->
        {:error, "unknown unit '#{symbol}'"}
    end
  end

  defp category_dim(catalog, category) do
    Map.get(catalog.categories[category], :dim, %{category => 1})
  end

  defp scale_dim(dim, exponent) do
    dim
    |> Map.new(fn {category, n} -> {category, n * exponent} end)
    |> drop_zero_exponents()
  end

  defp combine_dim(left, right) do
    left
    |> Map.merge(right, fn _category, a, b -> a + b end)
    |> drop_zero_exponents()
  end

  defp drop_zero_exponents(dim) do
    dim
    |> Enum.reject(fn {_category, exponent} -> exponent == 0 end)
    |> Map.new()
  end

  defp reject_duplicate_dim(catalog, name, dim) do
    case category_for_dim(catalog, dim) do
      {:ok, existing} ->
        {:error, "category :#{name} has the same dimension as :#{existing}"}

      :error ->
        :ok
    end
  end

  defp unit_entry(to_default, ast, inverse, aliases) do
    unit = %{
      to_default: to_default,
      to_default_ast: ast,
      from_default_ast: inverse
    }

    if aliases == [], do: unit, else: Map.put(unit, :aliases, aliases)
  end

  defp validate_aliases(_catalog, _name, []), do: :ok

  defp validate_aliases(catalog, name, aliases) when is_list(aliases) do
    Enum.reduce_while(aliases, MapSet.new(), fn unit_alias, seen ->
      cond do
        unit_alias in @reserved_words ->
          {:halt, {:error, "alias '#{unit_alias}' is a reserved keyword"}}

        not Regex.match?(@unit_name_pattern, unit_alias) ->
          {:halt, {:error, "invalid alias '#{unit_alias}'"}}

        unit_alias == name or MapSet.member?(seen, unit_alias) or name_taken?(catalog, unit_alias) ->
          {:halt, {:error, "alias '#{unit_alias}' already exists"}}

        true ->
          {:cont, MapSet.put(seen, unit_alias)}
      end
    end)
    |> case do
      %MapSet{} -> :ok
      {:error, _reason} = error -> error
    end
  end

  defp unit_or_alias?(units, name) do
    Map.has_key?(units, name) or
      Enum.any?(units, fn {_unit_name, unit} -> name in Map.get(unit, :aliases, []) end)
  end

  defp fetch_canonical_unit(catalog, name) do
    Enum.find_value(catalog.categories, :error, fn {_category, %{units: units}} ->
      case Map.fetch(units, name) do
        {:ok, unit} -> {:ok, unit}
        :error -> nil
      end
    end)
  end

  defp expand_alias_monomial(catalog, monomial) do
    Enum.reduce(monomial, %{}, fn {symbol, exponent}, acc ->
      combine_dim(acc, scale_dim(canonical_symbol_monomial(catalog, symbol), exponent))
    end)
  end

  defp canonical_symbol_monomial(catalog, symbol) do
    case canonical_name(catalog, symbol) do
      {:ok, canonical} -> parsed_canonical_monomial(canonical)
      :error -> %{symbol => 1}
    end
  end

  defp parsed_canonical_monomial(canonical) do
    case Formula.parse(canonical) do
      {:ok, monomial} -> monomial
      {:error, _} -> %{canonical => 1}
    end
  end

  defp reject_unknown_formula_symbols(catalog, monomial) do
    case Enum.find(Map.keys(monomial), &(category_for_unit(catalog, &1) == :error)) do
      nil -> :ok
      symbol -> {:error, "unknown unit '#{symbol}'"}
    end
  end

  defp reject_empty_formula_dimension(catalog, monomial, source) do
    case unit_dim(catalog, monomial) do
      {:ok, dim} when map_size(dim) == 0 ->
        {:error, "invalid formula '#{source}'"}

      {:ok, _dim} ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end

  defp canonical_name_in_units(units, name) do
    case Map.fetch(units, name) do
      {:ok, _} -> {:ok, name}
      :error -> alias_canonical_name(units, name)
    end
  end

  defp alias_canonical_name(units, name) do
    Enum.find_value(units, fn {canonical, unit} ->
      if name in Map.get(unit, :aliases, []), do: {:ok, canonical}
    end)
  end

  defp reject_duplicate_name(catalog, name) do
    if name_taken?(catalog, name) do
      {:error, "unit '#{name}' already exists"}
    else
      :ok
    end
  end

  defp name_taken?(catalog, name) do
    Enum.any?(catalog.categories, fn {_category, %{units: units}} ->
      unit_or_alias?(units, name)
    end)
  end

  defp reject_repeated_category(catalog, name) do
    if Regex.match?(@unit_name_pattern, name) do
      :ok
    else
      reject_formula_repeated_category(catalog, name)
    end
  end

  defp reject_formula_repeated_category(catalog, name) do
    case Formula.numerator_and_denominator(name) do
      {:ok, numerator, denominator} ->
        {num_cats, den_cats} =
          {[], []}
          |> add_symbol_dims(catalog, numerator, 1)
          |> add_symbol_dims(catalog, denominator, -1)

        overlap = MapSet.intersection(MapSet.new(num_cats), MapSet.new(den_cats))

        case overlap |> Enum.sort() |> List.first() do
          nil ->
            :ok

          category ->
            {:error,
             "formula '#{name}' repeats category :#{category} in the numerator and denominator"}
        end

      {:error, _reason} ->
        :ok
    end
  end

  defp add_symbol_dims({num, den}, catalog, symbols, side_sign) do
    Enum.reduce(symbols, {num, den}, fn symbol, acc ->
      add_symbol_dim(acc, catalog, symbol, side_sign)
    end)
  end

  defp add_symbol_dim({num, den}, catalog, symbol, side_sign) do
    case lookup_symbol_dim(catalog, symbol) do
      {:ok, dim} ->
        Enum.reduce(dim, {num, den}, &place_expanded_category(&1, &2, side_sign))

      {:error, _reason} ->
        {num, den}
    end
  end

  defp place_expanded_category({category, exponent}, {num, den}, side_sign) do
    cond do
      exponent * side_sign > 0 -> {[category | num], den}
      exponent * side_sign < 0 -> {num, [category | den]}
      true -> {num, den}
    end
  end

  defp parse_conversion(to_default) do
    ctx = Elex.new_context() |> Elex.add_variable!("value", 0)

    case Parser.parse(to_default, ctx) do
      {:ok, ast, :decimal} ->
        invert_conversion(ast)

      {:ok, _ast, _type} ->
        {:error, "conversion must be a numeric expression in 'value'"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp invert_conversion(ast) do
    case Inverter.invert(ast, "value") do
      {:ok, inverse} -> {:ok, ast, inverse}
      {:error, reason} -> {:error, reason}
    end
  end
end
