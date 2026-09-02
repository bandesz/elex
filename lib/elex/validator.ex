defmodule Elex.Validator do
  @moduledoc """
  Validates a parsed expression AST for type correctness.

  Checks that operators are applied to compatible types, variables exist in the
  context, and function calls match registered signatures. Used by
  [`Elex.Parser`](Elex.Parser) during parsing and available for direct AST validation.

  ## Examples

      context = Elex.new_context() |> Elex.add_variable!("x", 10)
      {:ok, ast, _} = Elex.Parser.parse("x + 5", context, validate: false)
      Elex.Validator.validate(ast, context)
      #=> {:ok, :decimal}

  """
  alias Elex.Context
  alias Elex.Dimension
  alias Elex.Unit
  alias Elex.Units.Catalog
  alias Elex.Units.Formula
  import Elex.Labels

  @reserved_keywords ["and", "or", "not", "null", "true", "false", "yes", "no"]
  @scalar_types [:decimal, :boolean, :string, :unknown, nil]
  @non_numeric_scalars [:boolean, :string, :unknown, nil]

  @doc """
  Validates an expression AST against a context.

  ## Parameters

  - `ast` - A parsed AST node from [`Elex.Parser`](Elex.Parser)
  - `ctx` - A [`Elex.Context`](Elex.Context) with variable types and functions

  ## Returns

  - `{:ok, type}` - The expression's result type (`:decimal`, `:boolean`, `:string`, `nil`, or `%Elex.Dimension{}`)
  - `{:error, reason}` - A human-readable validation error

  ## Examples

      context = Elex.new_context() |> Elex.add_variable!("x", 10)
      {:ok, ast, _} = Elex.Parser.parse("x > 0", context, validate: false)
      Elex.Validator.validate(ast, context)
      #=> {:ok, :boolean}

  """
  @spec validate(term(), Context.t()) ::
          {:ok, atom() | Dimension.t()} | {:error, String.t()}
  def validate(ast, ctx) do
    case infer(ast, ctx) do
      {:ok, {:dim, dim}} -> {:ok, %Dimension{monomial: dim}}
      {:ok, %Dimension{}} = ok -> ok
      {:ok, type} when type in @scalar_types -> {:ok, type}
      {:ok, type} when is_atom(type) -> {:ok, %Dimension{monomial: category_dim(ctx, type)}}
      other -> other
    end
  end

  @doc false
  def numeric_type?(%Dimension{}), do: true
  def numeric_type?(:decimal), do: true
  def numeric_type?(type) when type in @non_numeric_scalars, do: false
  def numeric_type?(type) when is_atom(type), do: true

  @doc """
  Checks that every AST node is the same numeric type.

  Numeric types are `:decimal` and `%Elex.Dimension{}`. Returns
  `{:ok, type}` when all arguments match, `{:mismatch, type}` when the first
  argument is not numeric, `{:mismatch, expected, got}` when later arguments
  differ, or `{:error, reason}` when validation of an argument fails.

  Use this from custom function `validate/2` callbacks that accept either a
  either a number or a quantity of one category. See
  [Advanced Topics](advanced.html#custom-functions).
  """
  @spec same_numeric_type([term()], Context.t()) ::
          {:ok, atom() | Dimension.t()}
          | {:mismatch, atom() | Dimension.t()}
          | {:mismatch, atom() | Dimension.t(), atom() | Dimension.t()}
          | {:error, String.t()}
  def same_numeric_type(asts, ctx) do
    Enum.reduce_while(asts, :unset, &accumulate_numeric_type(&1, &2, ctx))
    |> wrap_same_numeric()
  end

  @doc """
  Formats a `same_numeric_type/2` mismatch as a function error message.

  Mixed categories become `cannot mix length and mass`. A number
  mixed with a quantity is `cannot mix number and length`. A non-numeric first
  argument stays `name function expects number arguments, got …`.
  """
  @spec numeric_mismatch_message(
          String.t(),
          {:mismatch, atom() | Dimension.t()}
          | {:mismatch, atom() | Dimension.t(), atom() | Dimension.t()}
        ) :: String.t()
  def numeric_mismatch_message(name, {:mismatch, :decimal, actual}) do
    if numeric_type?(actual) and actual != :decimal do
      "cannot mix #{label(:decimal)} and #{label(actual)}"
    else
      "#{name} function expects number arguments, #{got(actual)}"
    end
  end

  def numeric_mismatch_message(_name, {:mismatch, expected, actual}) do
    "cannot mix #{label(expected)} and #{label(actual)}"
  end

  def numeric_mismatch_message(name, {:mismatch, actual}) do
    "#{name} function expects number arguments, #{got(actual)}"
  end

  defp accumulate_numeric_type(ast, expected, ctx) do
    case validate(ast, ctx) do
      {:error, reason} ->
        {:halt, {:error, reason}}

      {:ok, type} ->
        if literal_zero?(ast) do
          match_literal_zero(expected, ctx)
        else
          match_numeric_type(type, expected, ctx)
        end
    end
  end

  defp match_literal_zero(:unset, _ctx), do: {:cont, :zero}
  defp match_literal_zero(:zero, _ctx), do: {:cont, :zero}
  defp match_literal_zero(:decimal, _ctx), do: {:cont, :decimal}

  defp match_literal_zero(expected, ctx) do
    if additive_quantity_type?(expected, ctx) do
      {:cont, expected}
    else
      {:halt, {:mismatch, expected, :decimal}}
    end
  end

  defp match_numeric_type(type, :zero, ctx) do
    cond do
      not numeric_type?(type) ->
        {:halt, {:mismatch, :decimal, type}}

      type == :decimal or additive_quantity_type?(type, ctx) ->
        {:cont, type}

      true ->
        {:halt, {:mismatch, :decimal, type}}
    end
  end

  defp match_numeric_type(type, expected, _ctx) do
    cond do
      not numeric_type?(type) and expected == :unset ->
        {:halt, {:mismatch, type}}

      not numeric_type?(type) ->
        {:halt, {:mismatch, expected, type}}

      expected == :unset or type == expected ->
        {:cont, type}

      true ->
        {:halt, {:mismatch, expected, type}}
    end
  end

  defp wrap_same_numeric({:error, _} = err), do: err
  defp wrap_same_numeric({:mismatch, _, _} = mismatch), do: mismatch
  defp wrap_same_numeric({:mismatch, _} = mismatch), do: mismatch
  defp wrap_same_numeric(:zero), do: {:ok, :decimal}
  defp wrap_same_numeric(type), do: {:ok, type}

  @doc false
  @spec unify_with_literal_zero([term()], [term()], Context.t()) ::
          {:ok, term()} | {:mismatch, term(), term()}
  def unify_with_literal_zero(asts, types, ctx) when is_list(asts) do
    pairs = Enum.zip(asts, types)
    {zeros, rest} = Enum.split_with(pairs, fn {ast, _type} -> literal_zero?(ast) end)
    rest_types = rest |> Enum.map(&elem(&1, 1)) |> Enum.uniq()

    case {rest_types, zeros} do
      {[], []} ->
        {:ok, nil}

      {[], [_ | _]} ->
        {:ok, :decimal}

      {[type], []} ->
        {:ok, type}

      {[type], [_ | _]} ->
        unify_zero_with_type(type, ctx)

      {[type1, type2 | _], _} ->
        {:mismatch, type1, type2}
    end
  end

  defp unify_zero_with_type(:decimal, _ctx), do: {:ok, :decimal}

  defp unify_zero_with_type(type, ctx) do
    if additive_quantity_type?(type, ctx) do
      {:ok, type}
    else
      {:mismatch, type, :decimal}
    end
  end

  @doc false
  @spec quantity_unit(term(), Context.t()) :: {:ok, Unit.t()} | :none
  def quantity_unit(ast, ctx) do
    do_quantity_unit(ast, ctx)
  end

  @doc false
  @spec first_quantity_unit([term()], Context.t()) :: {:ok, Unit.t()} | :none
  def first_quantity_unit(asts, ctx) when is_list(asts) do
    Enum.find_value(asts, :none, fn ast ->
      case quantity_unit(ast, ctx) do
        {:ok, _} = ok -> ok
        _ -> nil
      end
    end)
  end

  defp do_quantity_unit({:unit, _value, symbol}, ctx) when is_binary(symbol) do
    {:ok, result_unit(symbol, ctx)}
  end

  defp do_quantity_unit({:var, name}, ctx) do
    case Map.fetch(ctx.variables, name) do
      {:ok, %{value: {_n, symbol}}} when is_binary(symbol) ->
        {:ok, Unit.new!(symbol)}

      {:ok, %{value: %Elex.Quantity{unit: %Unit{} = unit}}} ->
        {:ok, unit}

      {:ok, %{value: %Elex.Quantity{unit: symbol}}} when is_binary(symbol) ->
        {:ok, Unit.new!(symbol)}

      _ ->
        :none
    end
  end

  defp do_quantity_unit({:+, [left_ast, _right_ast]}, ctx), do: do_quantity_unit(left_ast, ctx)

  defp do_quantity_unit({:-, [left_ast, _right_ast]}, ctx), do: do_quantity_unit(left_ast, ctx)

  defp do_quantity_unit({:-, ast}, ctx) when not is_list(ast), do: do_quantity_unit(ast, ctx)

  defp do_quantity_unit({:*, [left_ast, right_ast]}, ctx) do
    combine_quantity_units(
      do_quantity_unit(left_ast, ctx),
      do_quantity_unit(right_ast, ctx),
      ctx
    )
  end

  defp do_quantity_unit({:/, [left_ast, right_ast]}, ctx) do
    divide_quantity_units(
      do_quantity_unit(left_ast, ctx),
      do_quantity_unit(right_ast, ctx),
      ctx
    )
  end

  defp do_quantity_unit({:func, name, arity, args_ast}, ctx) do
    case lookup_function(ctx, name, arity) do
      {:ok, function_module} -> quantity_unit_from_policy(function_module, args_ast, ctx)
      _ -> :none
    end
  end

  defp do_quantity_unit(_ast, _ctx), do: :none

  defp quantity_unit_from_policy(function_module, args_ast, ctx) do
    case Elex.Function.units(function_module) do
      policy when policy in [:point, :additive] -> first_quantity_unit(args_ast, ctx)
      :convert -> target_unit_from_ast(Enum.at(args_ast, 1), ctx)
      :wrap -> target_unit_from_ast(Enum.at(args_ast, 1), ctx)
      :none -> :none
      :unwrap -> :none
    end
  end

  defp target_unit_from_ast(target, ctx) when is_binary(target) do
    {:ok, result_unit(target, ctx)}
  rescue
    ArgumentError -> :none
  end

  defp target_unit_from_ast({:var, name}, %{variables: variables} = ctx) when is_binary(name) do
    case Map.get(variables, name) do
      %{value: value} when is_binary(value) -> target_unit_from_ast(value, ctx)
      _ -> :none
    end
  end

  defp target_unit_from_ast(_ast, _ctx), do: :none

  defp combine_quantity_units(:none, :none, _ctx), do: :none
  defp combine_quantity_units({:ok, unit}, :none, _ctx), do: {:ok, unit}
  defp combine_quantity_units(:none, {:ok, unit}, _ctx), do: {:ok, unit}

  defp combine_quantity_units({:ok, left}, {:ok, right}, ctx) do
    {left, right} = maybe_expand_derived_units(left, right, ctx)
    aligned = align_overlapping_monomial(left.monomial, right.monomial, ctx)
    unit_from_monomial(merge_exponents(left.monomial, aligned, &Kernel.+/2))
  end

  defp align_overlapping_monomial(left, right, %{units: %Catalog{} = catalog}) do
    targets =
      Enum.reduce(left, %{}, fn {symbol, _exponent}, acc ->
        case Catalog.category_for_unit(catalog, symbol) do
          {:ok, category} -> Map.put_new(acc, category, symbol)
          :error -> acc
        end
      end)

    Enum.reduce(right, %{}, fn {symbol, exponent}, acc ->
      target =
        case Catalog.category_for_unit(catalog, symbol) do
          {:ok, category} -> Map.get(targets, category, symbol)
          :error -> symbol
        end

      merge_exponents(acc, %{target => exponent}, &Kernel.+/2)
    end)
  end

  defp align_overlapping_monomial(_left, right, _ctx), do: right

  defp divide_quantity_units(:none, :none, _ctx), do: :none
  defp divide_quantity_units({:ok, unit}, :none, _ctx), do: {:ok, unit}

  defp divide_quantity_units(:none, {:ok, unit}, _ctx) do
    inverted = Map.new(unit.monomial, fn {symbol, exponent} -> {symbol, -exponent} end)
    unit_from_monomial(inverted)
  end

  defp divide_quantity_units({:ok, left}, {:ok, right}, ctx) do
    {left, right} = maybe_expand_derived_units(left, right, ctx)

    if same_unit_category?(left, right, ctx) do
      :none
    else
      aligned = align_overlapping_monomial(left.monomial, right.monomial, ctx)
      inverted = Map.new(aligned, fn {symbol, exponent} -> {symbol, -exponent} end)
      unit_from_monomial(merge_exponents(left.monomial, inverted, &Kernel.+/2))
    end
  end

  defp maybe_expand_derived_units(left, right, ctx) do
    if same_named_derived_units?(left, right, ctx) do
      {left, right}
    else
      {expand_derived_unit(left, ctx), expand_derived_unit(right, ctx)}
    end
  end

  defp same_named_derived_units?(left, right, ctx) do
    symbols =
      (Map.keys(left.monomial) ++ Map.keys(right.monomial))
      |> Enum.uniq()

    match?({:ok, _category}, named_derived_category(symbols, ctx))
  end

  defp named_derived_category(symbols, ctx) do
    categories = Enum.map(symbols, &derived_category_for_symbol(&1, ctx))

    case Enum.uniq(categories) do
      [category] when not is_nil(category) -> {:ok, category}
      _ -> :none
    end
  end

  defp derived_category_for_symbol(symbol, %{units: %Catalog{} = catalog}) do
    with {:ok, category} <- Catalog.category_for_unit(catalog, symbol),
         {_name, _identity} <- Catalog.formula_identity(catalog, category) do
      category
    else
      _ -> nil
    end
  end

  defp derived_category_for_symbol(_symbol, _ctx), do: nil

  defp expand_derived_unit(%Unit{monomial: monomial} = unit, ctx) do
    expanded =
      Enum.reduce(monomial, %{}, fn {symbol, exponent}, acc ->
        case derived_identity_monomial(symbol, ctx) do
          {:ok, hub_mono} ->
            merge_exponents(acc, scale_unit_monomial(hub_mono, exponent), &Kernel.+/2)

          :none ->
            merge_exponents(acc, %{symbol => exponent}, &Kernel.+/2)
        end
      end)

    case Unit.from_monomial(expanded) do
      nil -> unit
      expanded_unit -> expanded_unit
    end
  end

  defp derived_identity_monomial(symbol, %{units: %Catalog{} = catalog}) do
    with {:ok, category} <- Catalog.category_for_unit(catalog, symbol),
         {_name, identity} <- Catalog.formula_identity(catalog, category) do
      {:ok, identity}
    else
      _ -> :none
    end
  end

  defp derived_identity_monomial(_symbol, _ctx), do: :none

  defp scale_unit_monomial(monomial, exponent) do
    monomial
    |> Map.new(fn {symbol, n} -> {symbol, n * exponent} end)
    |> Map.reject(fn {_symbol, n} -> n == 0 end)
  end

  defp same_unit_category?(left, right, %{units: %Catalog{} = catalog}) do
    case {Catalog.unit_dim(catalog, left), Catalog.unit_dim(catalog, right)} do
      {{:ok, dim}, {:ok, dim}} -> true
      _ -> false
    end
  end

  defp same_unit_category?(_left, _right, _ctx), do: false

  defp unit_from_monomial(monomial) do
    case Unit.from_monomial(monomial) do
      nil -> :none
      %Unit{} = unit -> {:ok, unit}
    end
  end

  defp result_unit(name, %{units: %Catalog{} = catalog}) do
    case Catalog.canonical_name(catalog, name) do
      {:ok, canonical} -> Unit.new!(canonical)
      :error -> Unit.new!(name)
    end
  end

  defp result_unit(name, _ctx), do: Unit.new!(name)

  defp infer_power_suffix(symbol, ctx) do
    case Formula.parse(symbol) do
      {:ok, monomial} ->
        case Catalog.unit_dim(ctx.units, monomial) do
          {:ok, dim} -> {:ok, {:dim, dim}}
          {:error, _} -> {:error, "unknown unit '#{symbol}'"}
        end

      {:error, _} ->
        {:error, "unknown unit '#{symbol}'"}
    end
  end

  defp infer(%Decimal{}, _ctx), do: {:ok, :decimal}

  defp infer({:unit, _value, symbol}, ctx) do
    case Catalog.category_for_unit(ctx.units, symbol) do
      {:ok, category} -> {:ok, {:dim, category_dim(ctx, category)}}
      :error -> infer_power_suffix(symbol, ctx)
    end
  end

  defp infer(val, _ctx) when is_boolean(val), do: {:ok, :boolean}

  defp infer(val, _ctx) when is_binary(val), do: {:ok, :string}

  defp infer(nil, _ctx), do: {:ok, nil}

  defp infer({:not, ast}, ctx) do
    case infer(ast, ctx) do
      {:ok, :boolean} ->
        {:ok, :boolean}

      {:ok, type} ->
        {:error, "not operator cannot be used on #{type_label(type, ctx)} value"}

      {:error, err} ->
        {:error, err}
    end
  end

  defp infer({:-, ast}, ctx) when not is_list(ast) do
    case infer(ast, ctx) do
      {:ok, type} ->
        case numeric_dim(type, ctx) do
          {:ok, dim} ->
            {:ok, from_dims(dim)}

          :error ->
            {:error, "- operator cannot be used on #{type_label(type, ctx)} value"}
        end

      {:error, err} ->
        {:error, err}
    end
  end

  defp infer({:+, [left_ast, right_ast]}, ctx) do
    validate_add_sub_op(:+, left_ast, right_ast, ctx)
  end

  defp infer({:-, [left_ast, right_ast]}, ctx) do
    validate_add_sub_op(:-, left_ast, right_ast, ctx)
  end

  defp infer({:*, [left_ast, right_ast]}, ctx) do
    validate_mul_div_op(:*, left_ast, right_ast, ctx)
  end

  defp infer({:/, [left_ast, right_ast]}, ctx) do
    validate_mul_div_op(:/, left_ast, right_ast, ctx)
  end

  defp infer({:%, [left_ast, right_ast]}, ctx) do
    validate_decimal_op(:%, left_ast, right_ast, ctx)
  end

  defp infer({:<, [left_ast, right_ast]}, ctx) do
    validate_comparison_op(:<, left_ast, right_ast, ctx)
  end

  defp infer({:>, [left_ast, right_ast]}, ctx) do
    validate_comparison_op(:>, left_ast, right_ast, ctx)
  end

  defp infer({:<=, [left_ast, right_ast]}, ctx) do
    validate_comparison_op(:<=, left_ast, right_ast, ctx)
  end

  defp infer({:>=, [left_ast, right_ast]}, ctx) do
    validate_comparison_op(:>=, left_ast, right_ast, ctx)
  end

  defp infer({:==, [left_ast, right_ast]}, ctx) do
    validate_equality_op(:==, left_ast, right_ast, ctx)
  end

  defp infer({:!=, [left_ast, right_ast]}, ctx) do
    validate_equality_op(:!=, left_ast, right_ast, ctx)
  end

  defp infer({:and, [left_ast, right_ast]}, ctx) do
    validate_boolean_op(:and, left_ast, right_ast, ctx)
  end

  defp infer({:or, [left_ast, right_ast]}, ctx) do
    validate_boolean_op(:or, left_ast, right_ast, ctx)
  end

  defp infer({:var, name}, ctx) do
    if name not in @reserved_keywords do
      case Map.fetch(ctx.variables, name) do
        {:ok, variable} -> {:ok, typed(variable.type, ctx)}
        :error -> {:error, "variable '#{name}' does not exist"}
      end
    else
      {:error, "variable '#{name}' is a reserved keyword"}
    end
  end

  defp infer({:func, name, arity, args_ast}, ctx) do
    case lookup_function(ctx, name, arity) do
      {:ok, function_module} ->
        validate_function_call(function_module, name, args_ast, ctx)

      {:error, :too_few_args, min_arity} ->
        build_function_error(name, arity, [min_arity])

      {:error, :not_found} ->
        arities =
          Enum.filter(ctx.functions, fn {{fun, _arity}, _} -> fun == name end)
          |> Enum.map(fn {{_fun, fun_arity}, _} -> fun_arity end)
          |> Enum.sort()

        build_function_error(name, arity, arities)
    end
  end

  defp lookup_function(ctx, name, arity) do
    case Map.fetch(ctx.functions, {name, arity}) do
      {:ok, function_module} ->
        {:ok, function_module}

      :error ->
        lookup_variadic_function(ctx, name, arity)
    end
  end

  defp lookup_variadic_function(ctx, name, arity) do
    case Map.fetch(ctx.functions, {name, :variadic}) do
      {:ok, function_module} ->
        validate_variadic_arity(function_module, arity)

      :error ->
        {:error, :not_found}
    end
  end

  defp validate_variadic_arity(function_module, arity) do
    min_arity = function_module.signature().min_arity

    if arity >= min_arity do
      {:ok, function_module}
    else
      {:error, :too_few_args, min_arity}
    end
  end

  defp build_function_error(name, arity, []), do: {:error, "unknown function #{name}/#{arity}"}

  defp build_function_error(name, _arity, arities) do
    case arities do
      [0] -> {:error, "#{name} function expects no arguments"}
      [1] -> {:error, "#{name} function expects 1 argument"}
      _ -> {:error, "#{name} function expects #{join_with_or(arities)} arguments"}
    end
  end

  defp join_with_or([single]), do: to_string(single)

  defp join_with_or(list) when is_list(list) do
    {init, [last]} = Enum.split(list, -1)
    Enum.join(init, ", ") <> " or " <> to_string(last)
  end

  defp validate_decimal_op(op, a, b, ctx) do
    case [infer(a, ctx), infer(b, ctx)] do
      [{:ok, :decimal}, {:ok, :decimal}] ->
        {:ok, :decimal}

      [{:ok, type1}, {:ok, type2}] ->
        {:error, remainder_type_error(op, type1, type2, ctx)}

      [{:error, err}, _] ->
        {:error, err}

      [_, {:error, err}] ->
        {:error, err}
    end
  end

  defp remainder_type_error(op, type1, type2, ctx) do
    unitful = Enum.find([type1, type2], &category_type?/1)

    if unitful do
      "'#{op}' operator expects number arguments, #{got(unitful)}"
    else
      "'#{op}' operator cannot be used on #{type_label(type1, ctx)} and #{type_label(type2, ctx)}"
    end
  end

  defp validate_function_call(function_module, name, args_ast, ctx) do
    case function_module.validate(args_ast, ctx) do
      {:ok, type} ->
        case enforce_function_units(function_module, name, args_ast, ctx) do
          :ok -> {:ok, type}
          {:error, _} = err -> err
        end

      {:error, _} = err ->
        err
    end
  end

  defp validate_add_sub_op(op, a, b, ctx) do
    case [infer(a, ctx), infer(b, ctx)] do
      [{:ok, type1}, {:ok, type2}] ->
        case {numeric_dim(type1, ctx), numeric_dim(type2, ctx)} do
          {{:ok, dim}, {:ok, dim}} ->
            with :ok <- reject_non_additive_type(type1, ctx, "'#{op}'") do
              {:ok, from_dims(dim)}
            end

          _ ->
            add_sub_type_error(op, type1, type2, ctx)
        end

      [{:error, err}, _] ->
        {:error, err}

      [_, {:error, err}] ->
        {:error, err}
    end
  end

  defp validate_mul_div_op(op, a, b, ctx) do
    case [infer(a, ctx), infer(b, ctx)] do
      [{:ok, type1}, {:ok, type2}] ->
        with :ok <- reject_non_additive_type(type1, ctx, "'*' or '/'"),
             :ok <- reject_non_additive_type(type2, ctx, "'*' or '/'"),
             {:ok, left_dims} <- numeric_dim(type1, ctx),
             {:ok, right_dims} <- numeric_dim(type2, ctx) do
          {:ok, from_dims(combine_dims(op, left_dims, right_dims))}
        else
          {:error, reason} ->
            {:error, reason}

          :error ->
            {:error,
             "'#{op}' operator cannot be used on #{type_label(type1, ctx)} and #{type_label(type2, ctx)}"}
        end

      [{:error, err}, _] ->
        {:error, err}

      [_, {:error, err}] ->
        {:error, err}
    end
  end

  defp validate_comparison_op(op, a, b, ctx) do
    case [infer(a, ctx), infer(b, ctx)] do
      [{:ok, :decimal}, {:ok, :decimal}] ->
        {:ok, :boolean}

      [{:ok, :string}, {:ok, :string}] ->
        {:ok, :boolean}

      [{:ok, type1}, {:ok, type2}] ->
        case {numeric_dim(type1, ctx), numeric_dim(type2, ctx)} do
          {{:ok, dim}, {:ok, dim}} when map_size(dim) > 0 ->
            with :ok <- reject_mixed_non_additive_units([a, b], ctx) do
              {:ok, :boolean}
            end

          _ ->
            unitless_zero_or_compare_error(op, a, b, type1, type2, ctx)
        end

      [{:error, err}, _] ->
        {:error, err}

      [_, {:error, err}] ->
        {:error, err}
    end
  end

  defp category_type?({:dim, dim}) when map_size(dim) > 0, do: true
  defp category_type?(%Dimension{monomial: dim}) when map_size(dim) > 0, do: true
  defp category_type?({:dim, dim}) when map_size(dim) == 0, do: false
  defp category_type?(%Dimension{monomial: dim}) when map_size(dim) == 0, do: false
  defp category_type?(type) when type in @scalar_types, do: false
  defp category_type?(type) when is_atom(type), do: true

  defp mixed_unit_and_decimal?(:decimal, type), do: category_type?(type)
  defp mixed_unit_and_decimal?(type, :decimal), do: category_type?(type)
  defp mixed_unit_and_decimal?(_, _), do: false

  defp add_sub_type_error(op, type1, type2, ctx) do
    cond do
      mixed_unit_and_decimal?(type1, type2) ->
        {:error, mixed_unit_number_message(op, type1, type2, ctx)}

      category_type?(type1) and category_type?(type2) ->
        {:error,
         "cannot #{add_sub_verb(op)} #{type_label(type1, ctx)} and #{type_label(type2, ctx)}"}

      true ->
        {:error,
         "'#{op}' operator cannot be used on #{type_label(type1, ctx)} and #{type_label(type2, ctx)}"}
    end
  end

  defp add_sub_verb(:+), do: "add"
  defp add_sub_verb(:-), do: "subtract"

  defp mixed_unit_number_message(:+, type1, type2, ctx) do
    "cannot add #{type_label(type1, ctx)} and #{type_label(type2, ctx)}"
  end

  defp mixed_unit_number_message(:-, type1, type2, ctx) do
    "cannot subtract #{type_label(type2, ctx)} from #{type_label(type1, ctx)}"
  end

  defp comparison_type_error(op, type1, type2, ctx) do
    if category_type?(type1) or category_type?(type2) do
      {:error, "cannot compare #{type_label(type1, ctx)} and #{type_label(type2, ctx)}"}
    else
      {:error,
       "'#{op}' operator cannot be used on #{type_label(type1, ctx)} and #{type_label(type2, ctx)}"}
    end
  end

  defp typed(type, _ctx) when type in @scalar_types, do: type
  defp typed(type, ctx) when is_atom(type), do: {:dim, category_dim(ctx, type)}

  defp numeric_dim(:decimal, _ctx), do: {:ok, %{}}
  defp numeric_dim({:dim, dim}, _ctx), do: {:ok, dim}
  defp numeric_dim(%Dimension{monomial: dim}, _ctx), do: {:ok, dim}
  defp numeric_dim(type, _ctx) when type in @scalar_types, do: :error
  defp numeric_dim(type, ctx) when is_atom(type), do: {:ok, category_dim(ctx, type)}

  defp category_dim(ctx, category) do
    case ctx.units do
      %Catalog{categories: categories} ->
        case Map.fetch(categories, category) do
          {:ok, entry} -> Map.get(entry, :dim, %{category => 1})
          :error -> %{category => 1}
        end

      _ ->
        %{category => 1}
    end
  end

  defp from_dims(dim) when map_size(dim) == 0, do: :decimal
  defp from_dims(dim), do: {:dim, dim}

  defp reject_non_additive_type(type, ctx, op_label) do
    case numeric_dim(type, ctx) do
      {:ok, dim} ->
        if additive_dim?(dim, ctx) do
          :ok
        else
          {:error, "cannot use non-additive #{type_label(type, ctx)} with #{op_label}"}
        end

      :error ->
        :ok
    end
  end

  defp enforce_function_units(function_module, name, args_ast, ctx) do
    case Elex.Function.units(function_module) do
      :point -> reject_mixed_non_additive_units(unitful_arg_asts(args_ast, ctx), ctx)
      :additive -> reject_non_additive_function_args(args_ast, ctx, name)
      :none -> reject_unitful_function_args(args_ast, ctx, name)
      :convert -> :ok
      :wrap -> :ok
      :unwrap -> :ok
    end
  end

  defp unitful_arg_asts(asts, ctx) do
    Enum.filter(asts, fn ast ->
      case infer(ast, ctx) do
        {:ok, type} -> category_type?(type)
        _ -> false
      end
    end)
  end

  defp reject_non_additive_function_args(asts, ctx, name) do
    Enum.reduce_while(asts, :ok, fn ast, :ok ->
      reject_non_additive_function_arg(ast, ctx, name)
    end)
  end

  defp reject_non_additive_function_arg(ast, ctx, name) do
    case infer(ast, ctx) do
      {:ok, type} -> cont_or_halt(reject_non_additive_type(type, ctx, "'#{name}'"))
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp reject_unitful_function_args(asts, ctx, name) do
    Enum.reduce_while(asts, :ok, fn ast, :ok ->
      reject_unitful_function_arg(ast, ctx, name)
    end)
  end

  defp reject_unitful_function_arg(ast, ctx, name) do
    case infer(ast, ctx) do
      {:ok, type} ->
        if category_type?(type) do
          {:halt, {:error, "#{name} function does not accept unitful arguments"}}
        else
          {:cont, :ok}
        end

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp cont_or_halt(:ok), do: {:cont, :ok}
  defp cont_or_halt({:error, _} = err), do: {:halt, err}

  defp reject_mixed_non_additive_units(asts, ctx) do
    case non_additive_arg_type(asts, ctx) do
      {:error, _} = err ->
        err

      :additive ->
        :ok

      {:non_additive, type} ->
        monomials = Enum.map(asts, &operand_monomial(&1, ctx))

        if same_monomials?(monomials) do
          :ok
        else
          {:error, "cannot mix units of non-additive #{type_label(type, ctx)}"}
        end
    end
  end

  defp non_additive_arg_type(asts, ctx) do
    Enum.reduce_while(asts, :additive, &classify_arg_type(&1, &2, ctx))
  end

  defp classify_arg_type(ast, acc, ctx) do
    case infer(ast, ctx) do
      {:error, reason} -> {:halt, {:error, reason}}
      {:ok, type} -> classify_inferred_type(type, acc, ctx)
    end
  end

  defp classify_inferred_type(type, acc, ctx) do
    case numeric_dim(type, ctx) do
      {:ok, dim} -> classify_dim(dim, type, acc, ctx)
      :error -> {:cont, acc}
    end
  end

  defp classify_dim(dim, type, acc, ctx) do
    if additive_dim?(dim, ctx) do
      {:cont, acc}
    else
      {:halt, {:non_additive, type}}
    end
  end

  defp same_monomials?([first | rest]) do
    first_unit = Unit.new!(first)
    Enum.all?(rest, &Unit.same?(first_unit, Unit.new!(&1)))
  end

  defp unitless_zero_or_compare_error(op, a, b, type1, type2, ctx) do
    if unitless_zero_with_additive?(a, b, type1, type2, ctx) do
      {:ok, :boolean}
    else
      comparison_type_error(op, type1, type2, ctx)
    end
  end

  defp literal_zero?(%Decimal{} = decimal), do: Decimal.compare(decimal, 0) == :eq
  defp literal_zero?({:-, operand}) when not is_list(operand), do: literal_zero?(operand)
  defp literal_zero?(_ast), do: false

  defp unitless_zero_with_additive?(a, b, type1, type2, ctx) do
    (literal_zero?(a) and additive_quantity_type?(type2, ctx)) or
      (literal_zero?(b) and additive_quantity_type?(type1, ctx))
  end

  defp additive_quantity_type?(type, ctx) do
    case numeric_dim(type, ctx) do
      {:ok, dim} when map_size(dim) > 0 -> additive_dim?(dim, ctx)
      _ -> false
    end
  end

  defp additive_dim?(dim, _ctx) when map_size(dim) == 0, do: true

  defp additive_dim?(dim, %{units: %Catalog{} = catalog}) do
    case Catalog.category_for_dim(catalog, dim) do
      {:ok, category} -> Catalog.additive?(catalog, category)
      :error -> Enum.all?(Map.keys(dim), &Catalog.additive?(catalog, &1))
    end
  end

  defp additive_dim?(_dim, _ctx), do: true

  defp operand_monomial(ast, ctx) do
    case quantity_unit(ast, ctx) do
      {:ok, %Unit{monomial: monomial}} -> monomial
      _ -> %{}
    end
  end

  defp combine_dims(:*, left, right), do: merge_exponents(left, right, &Kernel.+/2)

  defp combine_dims(:/, left, right) do
    inverted = Map.new(right, fn {category, exponent} -> {category, -exponent} end)
    merge_exponents(left, inverted, &Kernel.+/2)
  end

  defp merge_exponents(left, right, combine) do
    left
    |> Map.merge(right, fn _key, a, b -> combine.(a, b) end)
    |> Map.reject(fn {_key, exponent} -> exponent == 0 end)
  end

  defp type_label({:dim, dim}, _ctx), do: label(%Dimension{monomial: dim})
  defp type_label(%Dimension{} = dim, _ctx), do: label(dim)
  defp type_label(type, _ctx), do: label(type)

  defp validate_equality_op(op, a, b, ctx) do
    case [infer(a, ctx), infer(b, ctx)] do
      [{:ok, type1}, {:ok, type2}]
      when type1 == type2 and type1 in [:decimal, :boolean, :string, nil] ->
        {:ok, :boolean}

      [{:ok, type1}, {:ok, type2}] ->
        case {numeric_dim(type1, ctx), numeric_dim(type2, ctx)} do
          {{:ok, dim}, {:ok, dim}} when map_size(dim) > 0 ->
            with :ok <- reject_mixed_non_additive_units([a, b], ctx) do
              {:ok, :boolean}
            end

          _ ->
            unitless_zero_or_compare_error(op, a, b, type1, type2, ctx)
        end

      [{:error, err}, _] ->
        {:error, err}

      [_, {:error, err}] ->
        {:error, err}
    end
  end

  defp validate_boolean_op(op, a, b, ctx) do
    case [infer(a, ctx), infer(b, ctx)] do
      [{:ok, :boolean}, {:ok, :boolean}] ->
        {:ok, :boolean}

      [{:ok, type1}, {:ok, type2}] ->
        {:error,
         "'#{op}' operator cannot be used on #{type_label(type1, ctx)} and #{type_label(type2, ctx)}"}

      [{:error, err}, _] ->
        {:error, err}

      [_, {:error, err}] ->
        {:error, err}
    end
  end
end
