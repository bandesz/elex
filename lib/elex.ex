defmodule Elex do
  @moduledoc """
  Elex is an expression language library for parsing, validating, and evaluating expressions.

  It supports:

  - Arithmetic operations (`+`, `-`, `*`, `/`, `%`) and unary minus
  - Comparison operators (`<`, `>`, `<=`, `>=`, `==`, `!=`) for decimals,
    booleans, strings, `null`, and same-dimension quantities
  - Boolean operations (`and`, `or`, `not`) with short-circuit evaluation
  - Literals: decimals, booleans (`true`/`false`, `yes`/`no`), strings, `null`
  - Variables and built-in functions (`abs`, `add_unit`, `between`, `ceil`,
    `clamp`, `coalesce`, `concat`, `contains`, `convert`, `ends_with`,
    `floor`, `if`, `length`, `lower`, `match`, `max`, `min`, `mod`, `pi`,
    `pow`, `rem`, `remove_unit`, `round`, `sqrt`, `starts_with`, `trim`,
    `upper`)
  - Variadic `min`, `max`, and `coalesce` (two or more arguments) and
    `concat` (zero or more arguments)
  - Type checking and validation
  - Optional caller-registered units (Elex ships no catalog); evaluate
    returns `%Elex.Quantity{}` when the result has a unit. Non-additive
    categories (`additive: false`) reject binary `+ − * /`; use
    `add_unit` / `remove_unit` for magnitude arithmetic. Formula strings
    use `|` for division (`m | s`, `km | h`), not `/`. `evaluate/3`
    accepts `unit:` and `category:`; `validate/3` accepts `category:` only

  ## Quick start

      context =
        Elex.new_context()
        |> Elex.add_variable!("x", 10)
        |> Elex.add_variable!("y", 5)

      Elex.evaluate("x + y * 2", context)
      #=> {:ok, #Decimal<20>}

      Elex.validate("x > 0", context)
      #=> {:ok, :boolean}

      Elex.extract_variables("x + y", context)
      #=> {:ok, ["x", "y"]}

  ## Guides

  - [Getting Started](getting-started.html)
  - [Expression Language](expression-language.html)
  - [Functions](functions.html)
  - [Units](units.html)
  - [Ash Integration](ash-integration.html)
  - [Advanced Topics](advanced.html)

  See [`Elex.Parser`](Elex.Parser) for parsing, [`Elex.Evaluator`](Elex.Evaluator) for
  direct AST evaluation, and [`Elex.Context`](Elex.Context) for custom variables and
  functions.
  """

  alias Elex.Context
  alias Elex.Labels
  alias Elex.Quantity
  alias Elex.Unit
  alias Elex.Units.Catalog

  @standard_functions [
    Elex.Functions.Abs,
    Elex.Functions.AddUnit,
    Elex.Functions.Between,
    Elex.Functions.Ceil,
    Elex.Functions.Clamp,
    Elex.Functions.Coalesce,
    Elex.Functions.Concat,
    Elex.Functions.Contains,
    Elex.Functions.Convert,
    Elex.Functions.EndsWith,
    Elex.Functions.Floor,
    Elex.Functions.If,
    Elex.Functions.Length,
    Elex.Functions.Lower,
    Elex.Functions.Match,
    Elex.Functions.Max,
    Elex.Functions.Min,
    Elex.Functions.Mod,
    Elex.Functions.Pi,
    Elex.Functions.Pow,
    Elex.Functions.Rem,
    Elex.Functions.RemoveUnit,
    Elex.Functions.Round,
    Elex.Functions.Sqrt,
    Elex.Functions.StartsWith,
    Elex.Functions.Trim,
    Elex.Functions.Upper
  ]

  @doc """
  Creates a new evaluation context with standard functions and optional variables.

  ## Parameters

  - `variables` - Map of variable names to [`Elex.Variable`](Elex.Variable) structs.
    Defaults to an empty map.

  ## Returns

  A [`Elex.Context`](Elex.Context) struct ready for parsing and evaluation.

  ## Examples

      Elex.new_context()

      Elex.new_context(%{
        "x" => %Elex.Variable{value: Decimal.new(1), type: :decimal}
      })

  """
  @spec new_context(%{optional(String.t()) => Elex.Variable.t()}) :: Context.t()
  def new_context(variables \\ %{}) when is_map(variables) do
    context = %Context{variables: variables}

    Enum.reduce(@standard_functions, context, fn module, acc ->
      Context.add_function(acc, module)
    end)
  end

  @doc """
  Returns the list of built-in function modules registered by `new_context/0`.

  Use this to distinguish standard functions from custom ones without relying on
  module-name heuristics.

  ## Examples

      Elex.list_standard_function_modules()
      #=> [Elex.Functions.Abs, Elex.Functions.AddUnit, ...]

  """
  @spec list_standard_function_modules() :: [module()]
  def list_standard_function_modules, do: @standard_functions

  @doc """
  Parses, validates, and evaluates an expression string.

  Returns `{:ok, result}` on success or `{:error, reason}` on parse, validation, or
  evaluation failure (including arithmetic errors such as division by zero).

  ## Parameters

  - `expression_string` - The expression to evaluate
  - `context` - A [`Elex.Context`](Elex.Context) with variables and functions
  - `opts` - Optional keywords. `unit:` converts a quantity result into a
    registered symbol or a formula over registered symbols (for example
    `"mm"`, `"km | h"`, or `"m | s^2"`). You do not need to register the
    formula as its own unit. Inside an expression, `convert(value, "mm")`
    is the same conversion as `unit: "mm"`, but a dim mismatch from
    `convert/2` is `cannot convert length to mass` while root `unit:` is
    `expression should return a valid length result` (the target's
    category). `category:` is the same compatibility check as
    `validate/3` (for example `category: :speed` requires `length | time`).
    `unit:` or `category:` with no catalog raises `ArgumentError`.
    Unknown option keys raise `ArgumentError`.

  ## Returns

  - `{:ok, result}` - The evaluated result (`Decimal.t()`, `boolean()`, `String.t()`,
    `nil`, or [`Elex.Quantity.t()`](Elex.Quantity))
  - `{:error, reason}` - A human-readable error message

  ## Examples

      context = Elex.new_context() |> Elex.add_variable!("x", 10)
      Elex.evaluate("x + 5", context)
      #=> {:ok, #Decimal<15>}

      # Quantity results and `unit:` need a catalog on the context
      # (`unit:` raises without one). See the Units guide.

  """
  @spec evaluate(String.t(), Context.t(), keyword()) ::
          {:ok, Decimal.t() | boolean() | String.t() | nil | Quantity.t()} | {:error, String.t()}
  def evaluate(expression_string, context, opts \\ []) do
    {unit, category} = evaluate_opts!(opts)
    require_units_catalog_for_unit!(unit, context)
    expected = required_category_dimension!(category, context)

    with {:ok, ast, type} <- Elex.Parser.parse(expression_string, context),
         {:ok, _type} <- match_optional_category(type, expected, category),
         {:ok, result} <- Elex.Evaluator.evaluate(ast, context),
         {:ok, result} <-
           Elex.Evaluator.apply_target_unit(result, unit, context, mismatch: :expected) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    e in RuntimeError ->
      {:error, Exception.message(e)}

    e in Decimal.Error ->
      {:error, humanize_decimal_error(e)}
  end

  defp humanize_decimal_error(%Decimal.Error{} = error) do
    error |> Exception.message() |> String.replace("_", " ")
  end

  @doc """
  Parses and validates an expression string without evaluating it.

  ## Parameters

  - `expression_string` - The expression to validate
  - `context` - A [`Elex.Context`](Elex.Context) with variables and functions
  - `opts` - Optional keywords. `category:` checks that a unitful result
    matches that catalog category's formula (for example `category: :speed`
    requires `length | time`). On success, validate still returns the
    inferred dimension, not the category atom. `category:` with no catalog,
    or an unknown category, raises `ArgumentError`. Unknown option keys
    (including `unit:`) raise `ArgumentError` — convert with `evaluate/3`.

  ## Returns

  - `{:ok, type}` - The expression's result type (`:decimal`, `:boolean`,
    `:string`, or [`Elex.Dimension.t()`](Elex.Dimension) for unitful results)
  - `{:error, reason}` - A human-readable error message

  ## Examples

      context = Elex.new_context() |> Elex.add_variable!("x", 10)
      Elex.validate("x > 0", context)
      #=> {:ok, :boolean}

      # Unitful results and `category:` need a catalog on the context
      # (`category:` raises without one). See the Units guide.

  """
  @spec validate(String.t(), Context.t()) ::
          {:ok, atom() | Elex.Dimension.t()} | {:error, String.t()}
  @spec validate(String.t(), Context.t(), keyword()) ::
          {:ok, atom() | Elex.Dimension.t()} | {:error, String.t()}
  def validate(expression_string, context, opts \\ []) do
    reject_unknown_opts!(opts, [:category], :validate)
    category = Keyword.get(opts, :category)
    expected = required_category_dimension!(category, context)

    case Elex.Parser.parse(expression_string, context) do
      {:ok, _ast, type} -> match_optional_category(type, expected, category)
      {:error, reason} -> {:error, reason}
    end
  end

  defp evaluate_opts!(opts) do
    reject_unknown_opts!(opts, [:unit, :category], :evaluate)
    {Keyword.get(opts, :unit), Keyword.get(opts, :category)}
  end

  defp reject_unknown_opts!(opts, allowed, api) do
    case Keyword.keys(opts) -- allowed do
      [] -> :ok
      [key | _] -> raise ArgumentError, unknown_option_message(key, api)
    end
  end

  defp unknown_option_message(:unit, :validate) do
    "unknown option :unit (use evaluate/3 to convert a result)"
  end

  defp unknown_option_message(key, _api) do
    "unknown option #{inspect(key)}"
  end

  defp require_units_catalog_for_unit!(nil, _context), do: :ok

  defp require_units_catalog_for_unit!(_unit, %Context{units: %Catalog{}}), do: :ok

  defp require_units_catalog_for_unit!(_unit, _context) do
    raise ArgumentError, "unit: requires a units catalog"
  end

  defp required_category_dimension!(nil, _context), do: nil

  defp required_category_dimension!(category, context) when is_atom(category) do
    case context.units do
      %Catalog{} = catalog ->
        case Catalog.dimension(catalog, category) do
          {:ok, dim} -> dim
          :error -> raise ArgumentError, "unknown category :#{category}"
        end

      _ ->
        raise ArgumentError, "category: requires a units catalog"
    end
  end

  defp match_optional_category(type, nil, _category), do: {:ok, type}

  defp match_optional_category(
         %Elex.Dimension{monomial: monomial} = type,
         %Elex.Dimension{monomial: monomial},
         _category
       ) do
    {:ok, type}
  end

  defp match_optional_category(type, _expected, category) do
    {:error, "#{category} was expected, got #{got_type(type)}"}
  end

  defp got_type(%Elex.Dimension{} = dim), do: to_string(dim)
  defp got_type(type), do: Labels.label(type)

  @doc """
  Extracts variable names referenced in an expression string.

  Parsing uses `context` (including a units catalog when attached) without
  validation, so variables need not exist.

  ## Parameters

  - `expression_string` - The expression to analyse
  - `context` - A [`Elex.Context`](Elex.Context) (catalog, functions)

  ## Returns

  - `{:ok, names}` - A deduplicated list of variable name strings
  - `{:error, reason}` - A parse error message

  ## Examples

      Elex.extract_variables("x + y * 2", Elex.new_context())
      #=> {:ok, ["x", "y"]}

  """
  @spec extract_variables(String.t(), Context.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def extract_variables(expression_string, %Context{} = context) do
    case Elex.Parser.parse(expression_string, context, validate: false) do
      {:ok, ast, _type} ->
        variables = extract_variables_from_ast(ast)
        {:ok, variables}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_variables_from_ast(ast) do
    ast
    |> do_extract_variables()
    |> Enum.uniq()
  end

  defp do_extract_variables({:var, variable_name}) when is_binary(variable_name) do
    [variable_name]
  end

  defp do_extract_variables({:func, _name, _arity, args}) when is_list(args) do
    Enum.flat_map(args, &do_extract_variables/1)
  end

  defp do_extract_variables({operator, operands}) when is_atom(operator) and is_list(operands) do
    Enum.flat_map(operands, &do_extract_variables/1)
  end

  defp do_extract_variables({operator, operand}) when is_atom(operator) do
    do_extract_variables(operand)
  end

  defp do_extract_variables(_literal) do
    []
  end

  @doc """
  Add multiple variables to a context at once.

  Returns `{:ok, context}` or `{:error, reason}`. Unitful `{number, unit}`
  or `%Elex.Quantity{}` values are rejected here — they require
  `category:` on `add_variable/4`. On error, later entries are not applied.
  Use `add_variables!/2` when piping.

  ## Examples

      {:ok, context} =
        add_variables(new_context(), %{"setting_a" => 10, "setting_b" => 20})

      context =
        new_context()
        |> add_variables!(%{"setting_a" => 10, "setting_b" => 20})

  """
  @spec add_variables(Context.t(), map()) :: {:ok, Context.t()} | {:error, String.t()}
  def add_variables(%Context{} = context, variables_map) when is_map(variables_map) do
    Enum.reduce_while(variables_map, {:ok, context}, fn {name, value}, {:ok, acc} ->
      case add_variable(acc, name, value) do
        {:ok, context} -> {:cont, {:ok, context}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  @doc """
  Same as `add_variables/2`, but returns the context or raises `ArgumentError`.
  """
  @spec add_variables!(Context.t(), map()) :: Context.t()
  def add_variables!(%Context{} = context, variables_map) when is_map(variables_map) do
    unwrap_context!(add_variables(context, variables_map))
  end

  @doc """
  Add a single variable to a context.

  Always returns `{:ok, context}` or `{:error, reason}`. A `{number, unit}`
  or `%Elex.Quantity{}` value must be paired with `category:`. Use
  `add_variable!/3` when piping.

  ## Examples

      {:ok, context} = add_variable(new_context(), "setting_a", 42.5)

      context = new_context() |> add_variable!("setting_a", 42.5)

      {:ok, context} =
        add_variable(context, "width", {10, "cm"}, category: :length)

      {:ok, context} =
        add_variable(context, "width", %Elex.Quantity{value: Decimal.new("10"), unit: "cm"},
          category: :length)

  """
  @spec add_variable(Context.t(), String.t(), any()) :: {:ok, Context.t()} | {:error, String.t()}
  @spec add_variable(Context.t(), String.t(), any(), keyword()) ::
          {:ok, Context.t()} | {:error, String.t()}
  def add_variable(%Context{} = context, name, value, opts \\ []) when is_binary(name) do
    category = Keyword.get(opts, :category)

    cond do
      category != nil and quantity_value?(value) ->
        add_categorized_variable(context, name, value, category)

      category != nil ->
        {:error, "variable '#{name}' has category #{category} but value is unitless"}

      quantity_value?(value) ->
        {:error, "variable '#{name}' has a unit but no category"}

      true ->
        variable = %Elex.Variable{value: value, type: infer_type(value)}
        {:ok, Context.add_variable(context, name, variable)}
    end
  end

  @doc """
  Same as `add_variable/3`, but returns the context or raises `ArgumentError`.
  """
  @spec add_variable!(Context.t(), String.t(), any()) :: Context.t()
  @spec add_variable!(Context.t(), String.t(), any(), keyword()) :: Context.t()
  def add_variable!(%Context{} = context, name, value, opts \\ []) when is_binary(name) do
    unwrap_context!(add_variable(context, name, value, opts))
  end

  defp unwrap_context!({:ok, context}), do: context
  defp unwrap_context!({:error, reason}), do: raise(ArgumentError, reason)

  defp quantity_value?({number, unit})
       when is_binary(unit) and (is_number(number) or is_struct(number, Decimal)) do
    true
  end

  defp quantity_value?(%Quantity{unit: unit}) when is_binary(unit), do: true
  defp quantity_value?(%Quantity{unit: %Unit{}}), do: true
  defp quantity_value?(_value), do: false

  defp add_categorized_variable(context, name, value, category) do
    unit = quantity_unit(value)

    with %Catalog{} = catalog <- context.units,
         {:ok, ^category} <- unit_category(catalog, unit) do
      variable = %Elex.Variable{
        value: normalize_quantity_value(catalog, value),
        type: category
      }

      {:ok, Context.add_variable(context, name, variable)}
    else
      {:ok, _other} ->
        {:error, "unit '#{unit_label(unit)}' is not in category #{category}"}

      _ ->
        {:error, "unknown unit '#{unit_label(unit)}'"}
    end
  end

  defp quantity_unit({_number, unit}) when is_binary(unit), do: unit
  defp quantity_unit(%Quantity{unit: unit}) when is_binary(unit), do: unit
  defp quantity_unit(%Quantity{unit: %Unit{} = unit}), do: unit

  defp normalize_quantity_value(catalog, {number, unit}) when is_binary(unit) do
    {number, canonical_unit_name(catalog, unit)}
  end

  defp normalize_quantity_value(catalog, %Quantity{unit: unit} = quantity)
       when is_binary(unit) do
    case Unit.new(canonical_unit_name(catalog, unit)) do
      {:ok, parsed} -> %{quantity | unit: parsed}
      {:error, _} -> quantity
    end
  end

  defp normalize_quantity_value(catalog, %Quantity{unit: %Unit{} = unit} = quantity) do
    %{quantity | unit: canonical_unit(catalog, unit)}
  end

  defp canonical_unit_name(catalog, name) do
    case Catalog.canonical_name(catalog, name) do
      {:ok, canonical} -> canonical
      :error -> name
    end
  end

  defp canonical_unit(catalog, %Unit{monomial: monomial} = unit) do
    case Enum.to_list(monomial) do
      [{symbol, 1}] ->
        case Unit.new(canonical_unit_name(catalog, symbol)) do
          {:ok, parsed} -> parsed
          {:error, _} -> unit
        end

      _ ->
        unit
    end
  end

  defp unit_category(catalog, unit) when is_binary(unit) do
    Catalog.category_for_unit(catalog, unit)
  end

  defp unit_category(catalog, %Unit{monomial: monomial}) do
    with {:ok, dim} <- monomial_dim(catalog, monomial) do
      Catalog.category_for_dim(catalog, dim)
    end
  end

  defp monomial_dim(catalog, monomial) do
    Enum.reduce_while(monomial, {:ok, %{}}, fn {symbol, exponent}, {:ok, acc} ->
      case symbol_dim(catalog, symbol, exponent) do
        {:ok, scaled} -> {:cont, {:ok, merge_dim(acc, scaled)}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp symbol_dim(catalog, symbol, exponent) do
    case Catalog.category_for_unit(catalog, symbol) do
      {:ok, category} ->
        dim = Map.get(catalog.categories[category], :dim, %{category => 1})
        {:ok, Map.new(dim, fn {name, n} -> {name, n * exponent} end)}

      :error ->
        :error
    end
  end

  defp merge_dim(left, right) do
    left
    |> Map.merge(right, fn _name, a, b -> a + b end)
    |> Map.reject(fn {_name, n} -> n == 0 end)
  end

  defp unit_label(unit) when is_binary(unit), do: unit

  defp unit_label(%Unit{} = unit) do
    unit |> inspect() |> String.trim_leading("#Elex.Unit<") |> String.trim_trailing(">")
  end

  defp infer_type(value) when is_integer(value), do: :decimal
  defp infer_type(value) when is_float(value), do: :decimal
  defp infer_type(%Decimal{}), do: :decimal
  defp infer_type(value) when is_binary(value), do: :string
  defp infer_type(value) when is_boolean(value), do: :boolean
  defp infer_type(nil), do: nil
  defp infer_type(_), do: :unknown
end
