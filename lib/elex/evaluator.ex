defmodule Elex.Evaluator do
  @moduledoc """
  Evaluates a parsed expression AST to a runtime value.

  `evaluate/2` returns `{:ok, result} | {:error, reason}`. `evaluate!/2` raises
  `RuntimeError` or `Decimal.Error` on evaluation failures. For a string-based API,
  prefer `Elex.evaluate/2`.

  ## Examples

      context = Elex.new_context() |> Elex.add_variable!("x", 10)
      {:ok, ast, _} = Elex.Parser.parse("x + 5", context)
      Elex.Evaluator.evaluate(ast, context)
      #=> {:ok, #Decimal<15>}

  """
  alias Elex.Context
  alias Elex.Quantity
  alias Elex.Unit
  alias Elex.Units.Catalog
  alias Elex.Units.Formula
  alias Elex.Validator
  import Elex.Labels

  @doc """
  Evaluates a parsed expression AST.

  ## Parameters

  - `ast` - A parsed AST node from [`Elex.Parser`](Elex.Parser)
  - `ctx` - A [`Elex.Context`](Elex.Context) with variable values and functions

  ## Returns

  - `{:ok, result}` - The evaluated result (`Decimal.t()`, `boolean()`, `String.t()`,
    `nil`, or [`Elex.Quantity.t()`](Elex.Quantity))
  - `{:error, reason}` - A human-readable error message

  ## Examples

      context = Elex.new_context() |> Elex.add_variable!("x", 10)
      {:ok, ast, _} = Elex.Parser.parse("x * 2", context)
      Elex.Evaluator.evaluate(ast, context)
      #=> {:ok, #Decimal<20>}

  """
  @spec evaluate(term(), Context.t()) ::
          {:ok, Decimal.t() | boolean() | String.t() | nil | Quantity.t()} | {:error, String.t()}
  def evaluate(ast, ctx) do
    {:ok, evaluate!(ast, ctx)}
  rescue
    e in RuntimeError -> {:error, Exception.message(e)}
    e in Decimal.Error -> {:error, humanize_decimal_error(e)}
  end

  @doc """
  Same as `evaluate/2`, but returns the result or raises `RuntimeError` /
  `Decimal.Error`.

  ## Examples

      context = Elex.new_context() |> Elex.add_variable!("x", 10)
      {:ok, ast, _} = Elex.Parser.parse("x * 2", context)
      Elex.Evaluator.evaluate!(ast, context)
      #=> #Decimal<20>

  """
  @spec evaluate!(term(), Context.t()) ::
          Decimal.t() | boolean() | String.t() | nil | Quantity.t()
  def evaluate!(ast, ctx)

  def evaluate!(%Decimal{} = decimal, _ctx), do: decimal

  def evaluate!({:unit, %Decimal{} = decimal, symbol}, ctx) when is_binary(symbol) do
    quantity(decimal, result_unit(symbol, ctx))
  end

  def evaluate!(val, _ctx) when is_boolean(val), do: val

  def evaluate!(val, _ctx) when is_binary(val), do: val

  def evaluate!(nil, _ctx), do: nil

  def evaluate!({:not, ast}, ctx) do
    case evaluate!(ast, ctx) do
      v when is_boolean(v) ->
        !v

      _ ->
        raise("not operator can only be used with #{label(:boolean)} values")
    end
  end

  def evaluate!({:-, ast}, ctx) when not is_list(ast) do
    case evaluate!(ast, ctx) do
      %Decimal{} = decimal ->
        Decimal.negate(decimal)

      %Quantity{value: value, unit: unit} ->
        quantity(Decimal.negate(value), unit)

      _ ->
        raise("- operator can only be used with #{label(:decimal)} values")
    end
  end

  def evaluate!({:+, [left_ast, right_ast]}, ctx) do
    case {evaluate!(left_ast, ctx), evaluate!(right_ast, ctx)} do
      {%Quantity{} = left, %Quantity{} = right} ->
        reject_non_additive!(left, ctx, "'+'")
        reject_non_additive!(right, ctx, "'+'")
        right_value = convert_to(right, left.unit, ctx)
        quantity(Decimal.add(left.value, right_value), left.unit)

      {%Quantity{} = left, _right} ->
        raise "cannot add #{category_label(left, ctx)} and number"

      {_left, %Quantity{} = right} ->
        raise "cannot add number and #{category_label(right, ctx)}"

      {left, right} ->
        Decimal.add(left, right)
    end
  end

  def evaluate!({:-, [left_ast, right_ast]}, ctx) do
    case {evaluate!(left_ast, ctx), evaluate!(right_ast, ctx)} do
      {%Quantity{} = left, %Quantity{} = right} ->
        reject_non_additive!(left, ctx, "'-'")
        reject_non_additive!(right, ctx, "'-'")
        right_value = convert_to(right, left.unit, ctx)

        quantity(Decimal.add(left.value, Decimal.negate(right_value)), left.unit)

      {_left, %Quantity{} = right} ->
        raise "cannot subtract #{category_label(right, ctx)} from number"

      {%Quantity{} = left, _right} ->
        raise "cannot subtract number from #{category_label(left, ctx)}"

      {left, right} ->
        Decimal.add(left, Decimal.negate(right))
    end
  end

  def evaluate!({:*, [left_ast, right_ast]}, ctx) do
    case {evaluate!(left_ast, ctx), evaluate!(right_ast, ctx)} do
      {%Quantity{} = left, %Quantity{} = right} ->
        reject_non_additive!(left, ctx, "'*' or '/'")
        reject_non_additive!(right, ctx, "'*' or '/'")
        multiply_quantities(left, right, ctx)

      {%Quantity{} = quantity, scalar} when not is_struct(scalar, Quantity) ->
        reject_non_additive!(quantity, ctx, "'*' or '/'")
        quantity(Decimal.mult(quantity.value, scalar), quantity.unit)

      {scalar, %Quantity{} = quantity} when not is_struct(scalar, Quantity) ->
        reject_non_additive!(quantity, ctx, "'*' or '/'")
        quantity(Decimal.mult(scalar, quantity.value), quantity.unit)

      {left, right} ->
        Decimal.mult(left, right)
    end
  end

  def evaluate!({:/, [left_ast, right_ast]}, ctx) do
    case {evaluate!(left_ast, ctx), evaluate!(right_ast, ctx)} do
      {%Quantity{} = left, %Quantity{} = right} ->
        reject_non_additive!(left, ctx, "'*' or '/'")
        reject_non_additive!(right, ctx, "'*' or '/'")
        divide_quantities(left, right, ctx)

      {%Quantity{} = quantity, scalar} when not is_struct(scalar, Quantity) ->
        reject_non_additive!(quantity, ctx, "'*' or '/'")
        quantity(Decimal.div(quantity.value, scalar), quantity.unit)

      {scalar, %Quantity{} = quantity} when not is_struct(scalar, Quantity) ->
        reject_non_additive!(quantity, ctx, "'*' or '/'")
        monomial = invert_monomial(unit_monomial(quantity.unit))
        quantity_or_decimal(Decimal.div(scalar, quantity.value), monomial)

      {left, right} ->
        Decimal.div(left, right)
    end
  end

  def evaluate!({:%, [left_ast, right_ast]}, ctx) do
    Decimal.rem(evaluate!(left_ast, ctx), evaluate!(right_ast, ctx))
  end

  def evaluate!({:<, [left_ast, right_ast]}, ctx) do
    compare(evaluate!(left_ast, ctx), evaluate!(right_ast, ctx), ctx) == :lt
  end

  def evaluate!({:>, [left_ast, right_ast]}, ctx) do
    compare(evaluate!(left_ast, ctx), evaluate!(right_ast, ctx), ctx) == :gt
  end

  def evaluate!({:<=, [left_ast, right_ast]}, ctx) do
    compare(evaluate!(left_ast, ctx), evaluate!(right_ast, ctx), ctx) in [:lt, :eq]
  end

  def evaluate!({:>=, [left_ast, right_ast]}, ctx) do
    compare(evaluate!(left_ast, ctx), evaluate!(right_ast, ctx), ctx) in [:gt, :eq]
  end

  def evaluate!({:==, [left_ast, right_ast]}, ctx) do
    left = evaluate!(left_ast, ctx)
    right = evaluate!(right_ast, ctx)

    {left, right} = {
      wrap_unitless_zero(left, right, ctx),
      wrap_unitless_zero(right, left, ctx)
    }

    case {left, right} do
      {%Decimal{}, %Decimal{}} -> Decimal.compare(left, right) == :eq
      {%Quantity{}, %Quantity{}} -> compare(left, right, ctx) == :eq
      {_, _} -> left == right
    end
  end

  def evaluate!({:!=, [left_ast, right_ast]}, ctx) do
    left = evaluate!(left_ast, ctx)
    right = evaluate!(right_ast, ctx)

    {left, right} = {
      wrap_unitless_zero(left, right, ctx),
      wrap_unitless_zero(right, left, ctx)
    }

    case {left, right} do
      {%Decimal{}, %Decimal{}} -> Decimal.compare(left, right) != :eq
      {%Quantity{}, %Quantity{}} -> compare(left, right, ctx) != :eq
      {_, _} -> left != right
    end
  end

  def evaluate!({:and, [left_ast, right_ast]}, ctx) do
    case evaluate!(left_ast, ctx) do
      false -> false
      true -> evaluate!(right_ast, ctx)
    end
  end

  def evaluate!({:or, [left_ast, right_ast]}, ctx) do
    case evaluate!(left_ast, ctx) do
      true -> true
      false -> evaluate!(right_ast, ctx)
    end
  end

  def evaluate!({:var, name}, ctx) do
    variable = Map.fetch!(ctx.variables, name)

    case variable.value do
      {n, unit} when is_binary(unit) ->
        quantity(to_decimal(n), unit)

      %Quantity{} = quantity ->
        quantity(quantity.value, quantity.unit)

      value ->
        value
    end
  end

  def evaluate!({:func, name, arity, args_ast}, ctx) do
    function_module = lookup_function!(ctx, name, arity)

    result =
      if function_exported?(function_module, :evaluate_call, 2) do
        function_module.evaluate_call(args_ast, ctx)
      else
        evaluated_args =
          args_ast
          |> Enum.map(&evaluate!(&1, ctx))
          |> align_quantity_args(function_module, ctx)

        call_function(function_module, evaluated_args, ctx)
      end

    unwrap_call_result(result, name, arity)
  end

  @doc false
  def align_to_unit(value, :none, _ctx), do: value
  def align_to_unit(value, nil, _ctx), do: value
  def align_to_unit(value, {:ok, unit}, ctx), do: align_to_unit(value, unit, ctx)

  def align_to_unit(%Quantity{} = quantity, %Unit{} = unit, ctx) do
    if additive_unit?(unit, ctx) do
      quantity(convert_to(quantity, unit, ctx), unit)
    else
      reject_mixed_non_additive_units!(unit, quantity.unit, quantity, ctx)
      quantity
    end
  end

  def align_to_unit(value, _unit, _ctx), do: value

  @doc false
  def validate_conversion(from_category, to_unit, ctx)
      when is_atom(from_category) and is_binary(to_unit) do
    default = Catalog.categories(ctx.units)[from_category]

    if is_binary(default) do
      dummy = quantity(Decimal.new(1), default)

      case apply_target_unit(dummy, to_unit, ctx) do
        {:ok, _} -> :ok
        {:error, _} = err -> err
      end
    else
      {:error, "cannot convert to the target unit"}
    end
  end

  @doc false
  def validate_conversion(value_ast, from_type, to_unit, ctx) when is_binary(to_unit) do
    case conversion_dummy(value_ast, from_type, ctx) do
      {:error, _} = err ->
        err

      dummy ->
        case apply_target_unit(dummy, to_unit, ctx) do
          {:ok, _} -> :ok
          {:error, _} = err -> err
        end
    end
  end

  @doc false
  def apply_target_unit(result, to_unit, ctx, opts \\ [])

  def apply_target_unit(result, nil, _ctx, _opts), do: {:ok, result}

  def apply_target_unit(result, to_unit, ctx, opts) when is_binary(to_unit) do
    case String.trim(to_unit) do
      "" -> {:error, "unit is empty"}
      trimmed -> apply_trimmed_target_unit(result, trimmed, ctx, mismatch_style(opts))
    end
  end

  defp mismatch_style(opts), do: Keyword.get(opts, :mismatch, :convert)

  defp apply_trimmed_target_unit(%Quantity{unit: from_unit} = quantity, to_unit, ctx, style) do
    case Catalog.canonical_name(ctx.units, to_unit) do
      {:ok, canonical} ->
        apply_registered_target(quantity, from_unit, canonical, ctx, style)

      :error ->
        apply_formula_target(quantity, to_unit, ctx, style)
    end
  end

  defp apply_trimmed_target_unit(result, to_unit, ctx, _style) do
    case Catalog.category_for_unit(ctx.units, to_unit) do
      {:ok, _} ->
        {:error, "cannot convert #{result_kind(result)} to a unit"}

      :error ->
        non_quantity_unknown_target(result, to_unit, ctx)
    end
  end

  defp non_quantity_unknown_target(result, to_unit, ctx) do
    case Catalog.parse_formula(ctx.units, to_unit) do
      {:ok, _monomial} ->
        {:error, "cannot convert #{result_kind(result)} to a unit"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp conversion_dummy(value_ast, from_category, ctx) do
    case Validator.quantity_unit(value_ast, ctx) do
      {:ok, unit} -> quantity(Decimal.new(1), unit)
      :none -> conversion_hub_dummy(from_category, ctx)
    end
  end

  defp conversion_hub_dummy(%Elex.Dimension{monomial: monomial}, ctx) do
    case Catalog.category_for_dim(ctx.units, monomial) do
      {:ok, category} -> conversion_hub_dummy(category, ctx)
      :error -> {:error, "cannot convert to the target unit"}
    end
  end

  defp conversion_hub_dummy(from_category, ctx) when is_atom(from_category) do
    default = Catalog.categories(ctx.units)[from_category]

    if is_binary(default) do
      quantity(Decimal.new(1), default)
    else
      {:error, "cannot convert to the target unit"}
    end
  end

  defp apply_registered_target(quantity, from_unit, to_unit, ctx, style) do
    with {:ok, from_dim} <- unit_dim(from_unit, ctx),
         {:ok, target_dim} <- Catalog.unit_dim(ctx.units, %{to_unit => 1}),
         :ok <- matching_target_dim(from_dim, target_dim, to_unit, ctx.units, style) do
      try do
        value = convert_to(quantity, to_unit, ctx)
        {:ok, quantity(value, registered_unit(to_unit))}
      rescue
        e in RuntimeError -> {:error, Exception.message(e)}
      end
    end
  end

  defp apply_formula_target(%Quantity{unit: from_unit} = quantity, to_unit, ctx, style) do
    with {:ok, target_monomial} <- Catalog.parse_formula(ctx.units, to_unit),
         :ok <- reject_non_additive_target(target_monomial, ctx),
         {:ok, target_dim} <- formula_target_dim(target_monomial, ctx.units),
         {:ok, from_dim} <- unit_dim(from_unit, ctx),
         :ok <- matching_target_dim(from_dim, target_dim, to_unit, ctx.units, style) do
      try do
        target = Unit.from_monomial(target_monomial)
        value = convert_to(quantity, target, ctx)
        {:ok, quantity(value, target)}
      rescue
        e in RuntimeError -> {:error, Exception.message(e)}
      end
    end
  end

  defp result_category(%Unit{monomial: monomial}, catalog) do
    result_category(monomial, catalog)
  end

  defp result_category(from_unit, catalog) when is_binary(from_unit) do
    case Catalog.category_for_unit(catalog, from_unit) do
      {:ok, _} = ok -> ok
      :error -> {:error, "unknown unit '#{from_unit}'"}
    end
  end

  defp result_category(from_unit, catalog) when is_map(from_unit) do
    with {:ok, dim} <- formula_target_dim(from_unit, catalog) do
      case Catalog.category_for_dim(catalog, dim) do
        {:ok, _} = ok -> ok
        :error -> {:error, "cannot convert to the target unit"}
      end
    end
  end

  defp formula_target_dim(monomial, catalog) do
    Enum.reduce_while(monomial, {:ok, %{}}, fn {symbol, exponent}, {:ok, acc} ->
      case Catalog.category_for_unit(catalog, symbol) do
        {:ok, category} ->
          dim = Map.get(catalog.categories[category], :dim, %{category => 1})
          {:cont, {:ok, combine_monomials(acc, scale_dim(dim, exponent))}}

        :error ->
          {:halt, {:error, "unknown unit '#{symbol}'"}}
      end
    end)
  end

  defp matching_target_dim(from_dim, target_dim, to_unit, catalog, style) do
    if from_dim == target_dim do
      :ok
    else
      {:error,
       dim_mismatch_error(
         dim_label(from_dim, catalog),
         dim_label(target_dim, catalog),
         to_unit,
         style
       )}
    end
  end

  defp dim_label(dim, _catalog) when map_size(dim) == 0, do: label(:decimal)

  defp dim_label(dim, catalog) do
    case Catalog.category_for_dim(catalog, dim) do
      {:ok, category} -> category
      :error -> Elex.Dimension.formula(%Elex.Dimension{monomial: dim})
    end
  end

  defp dim_mismatch_error(_from_category, to_category, _to_unit, :expected)
       when is_atom(to_category) do
    "expression should return a valid #{label(to_category)} result"
  end

  defp dim_mismatch_error(_from_category, label, _to_unit, :expected) when is_binary(label) do
    "expression should return a valid #{label} result"
  end

  defp dim_mismatch_error(from_category, to_category, _to_unit, :convert)
       when is_atom(to_category) do
    "cannot convert #{from_category} to #{to_category}"
  end

  defp dim_mismatch_error(from_category, _label, to_unit, :convert) do
    "cannot convert #{from_category} to '#{to_unit}'"
  end

  defp call_function(function_module, args, ctx) do
    if function_exported?(function_module, :call, 2) do
      function_module.call(args, ctx)
    else
      function_module.call(args)
    end
  end

  defp unwrap_call_result({:ok, result}, _name, _arity), do: result

  defp unwrap_call_result({:error, reason}, _name, _arity) when is_binary(reason) do
    raise reason
  end

  defp unwrap_call_result({:error, reason}, name, arity) do
    raise "Error calling function #{name}/#{arity}: #{inspect(reason)}"
  end

  defp lookup_function!(ctx, name, arity) do
    case Map.fetch(ctx.functions, {name, arity}) do
      {:ok, function_module} ->
        function_module

      :error ->
        lookup_variadic_function!(ctx, name, arity)
    end
  end

  defp lookup_variadic_function!(ctx, name, arity) do
    case Map.fetch(ctx.functions, {name, :variadic}) do
      {:ok, function_module} ->
        validate_variadic_arity!(function_module, name, arity)

      :error ->
        raise "Function #{name}/#{arity} not found"
    end
  end

  defp validate_variadic_arity!(function_module, name, arity) do
    min_arity = function_module.signature().min_arity

    if arity >= min_arity do
      function_module
    else
      raise "Function #{name}/#{arity} not found"
    end
  end

  defp compare(%Decimal{} = left, %Decimal{} = right, _ctx), do: Decimal.compare(left, right)

  defp compare(%Quantity{} = left, %Quantity{} = right, ctx) do
    reject_mixed_non_additive_units!(left.unit, right.unit, left, ctx)
    Decimal.compare(left.value, convert_to(right, left.unit, ctx))
  end

  defp compare(%Quantity{} = left, %Decimal{} = right, ctx) do
    case wrap_unitless_zero(right, left, ctx) do
      %Quantity{} = wrapped -> compare(left, wrapped, ctx)
    end
  end

  defp compare(%Decimal{} = left, %Quantity{} = right, ctx) do
    case wrap_unitless_zero(left, right, ctx) do
      %Quantity{} = wrapped -> compare(wrapped, right, ctx)
    end
  end

  defp compare(left, right, _ctx) when is_binary(left) and is_binary(right) do
    cond do
      left < right -> :lt
      left > right -> :gt
      true -> :eq
    end
  end

  defp align_quantity_args(args, function_module, ctx) do
    name = function_module.signature().name |> to_string()

    case Elex.Function.units(function_module) do
      :none ->
        reject_unitful_args!(args, name)
        args

      :convert ->
        args

      :wrap ->
        args

      :unwrap ->
        args

      :additive ->
        reject_non_additive_args!(args, ctx, "'#{name}'")
        align_to_first_quantity(args, ctx)

      :point ->
        align_to_first_quantity(args, ctx)
    end
  end

  defp align_to_first_quantity(args, ctx) do
    case Enum.find(args, &match?(%Quantity{}, &1)) do
      %Quantity{unit: unit} -> Enum.map(args, &align_to_unit(&1, unit, ctx))
      _ -> args
    end
  end

  defp reject_non_additive!(%Quantity{} = quantity, ctx, op_label) do
    if additive_quantity?(quantity, ctx) do
      :ok
    else
      raise "cannot use non-additive #{category_label(quantity, ctx)} with #{op_label}"
    end
  end

  defp reject_non_additive_args!(args, ctx, op_label) do
    Enum.each(args, fn
      %Quantity{} = quantity -> reject_non_additive!(quantity, ctx, op_label)
      _ -> :ok
    end)
  end

  defp reject_unitful_args!(args, name) do
    Enum.each(args, fn
      %Quantity{} -> raise "#{name} function does not accept unitful arguments"
      _ -> :ok
    end)
  end

  defp reject_mixed_non_additive_units!(left_unit, right_unit, quantity, ctx) do
    if additive_unit?(left_unit, ctx) or
         Unit.same?(to_unit(left_unit), to_unit(right_unit)) do
      :ok
    else
      raise "cannot mix units of non-additive #{category_label(quantity, ctx)}"
    end
  end

  defp reject_non_additive_target(monomial, ctx) do
    case non_additive_symbol(monomial, ctx) do
      nil -> :ok
      symbol -> {:error, "cannot use non-additive unit '#{symbol}' in a compound target"}
    end
  end

  defp non_additive_symbol(monomial, ctx) do
    Enum.find_value(monomial, fn {symbol, _exponent} ->
      non_additive_category_symbol(symbol, ctx)
    end)
  end

  defp non_additive_category_symbol(symbol, ctx) do
    case Catalog.category_for_unit(ctx.units, symbol) do
      {:ok, category} -> non_additive_if_category(symbol, category, ctx)
      :error -> nil
    end
  end

  defp non_additive_if_category(symbol, category, ctx) do
    if Catalog.additive?(ctx.units, category), do: nil, else: symbol
  end

  defp wrap_unitless_zero(%Decimal{} = decimal, %Quantity{} = other, ctx) do
    if Decimal.compare(decimal, 0) == :eq and additive_quantity?(other, ctx) do
      quantity(decimal, other.unit)
    else
      decimal
    end
  end

  defp wrap_unitless_zero(value, _other, _ctx), do: value

  defp additive_quantity?(%Quantity{unit: unit}, ctx), do: additive_unit?(unit, ctx)

  defp additive_unit?(unit, %{units: %Catalog{} = catalog}) do
    case formula_target_dim(unit_monomial(unit), catalog) do
      {:ok, dim} when map_size(dim) == 0 ->
        true

      {:ok, dim} ->
        case Catalog.category_for_dim(catalog, dim) do
          {:ok, category} -> Catalog.additive?(catalog, category)
          :error -> Enum.all?(Map.keys(dim), &Catalog.additive?(catalog, &1))
        end

      {:error, _} ->
        true
    end
  end

  defp additive_unit?(_unit, _ctx), do: true

  defp category_label(%Quantity{unit: unit}, ctx), do: category_label(unit, ctx)

  defp category_label(unit, ctx) do
    case result_category(to_unit(unit), ctx.units) do
      {:ok, category} -> label(category)
      {:error, _} -> "unit"
    end
  end

  defp multiply_quantities(left, right, ctx) do
    {left, right} = maybe_expand_derived(left, right, ctx)
    {right_value, right_monomial} = align_right_to_left(left.unit, right, ctx)
    monomial = combine_monomials(unit_monomial(left.unit), right_monomial)
    quantity_or_decimal(Decimal.mult(left.value, right_value), monomial)
  end

  defp divide_quantities(left, right, ctx) do
    {left, right} = maybe_expand_derived(left, right, ctx)

    if same_category_units?(left.unit, right.unit, ctx) do
      Decimal.div(left.value, convert_to(right, left.unit, ctx))
    else
      {right_value, right_monomial} = align_right_to_left(left.unit, right, ctx)

      monomial =
        combine_monomials(unit_monomial(left.unit), invert_monomial(right_monomial))

      quantity_or_decimal(Decimal.div(left.value, right_value), monomial)
    end
  end

  defp maybe_expand_derived(left, right, ctx) do
    if same_named_derived_units?(left.unit, right.unit, ctx) do
      {left, right}
    else
      {expand_derived_aliases(left, ctx), expand_derived_aliases(right, ctx)}
    end
  end

  defp same_named_derived_units?(left_unit, right_unit, ctx) do
    symbols =
      (Map.keys(unit_monomial(left_unit)) ++ Map.keys(unit_monomial(right_unit)))
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

  defp derived_category_for_symbol(symbol, ctx) do
    with {:ok, category} <- Catalog.category_for_unit(ctx.units, symbol),
         {_name, _identity} <- Catalog.formula_identity(ctx.units, category) do
      category
    else
      _ -> nil
    end
  end

  defp expand_derived_aliases(%Quantity{value: value, unit: unit} = quantity, ctx) do
    {value, monomial} =
      Enum.reduce(unit_monomial(unit), {value, %{}}, fn {symbol, exponent}, {acc_value, acc} ->
        case derived_alias_hub(symbol, ctx) do
          {:ok, hub_value, hub_mono} ->
            scaled = Decimal.mult(acc_value, integer_pow(hub_value, exponent))
            {scaled, combine_monomials(acc, scale_monomial(hub_mono, exponent))}

          :none ->
            {acc_value, combine_monomials(acc, %{symbol => exponent})}
        end
      end)

    case Unit.from_monomial(monomial) do
      nil -> quantity
      expanded -> quantity(value, expanded)
    end
  end

  defp derived_alias_hub(symbol, ctx) do
    with {:ok, category} <- Catalog.category_for_unit(ctx.units, symbol),
         {_name, _identity} <- Catalog.formula_identity(ctx.units, category) do
      {hub_value, hub_mono} = named_to_base_hub(Decimal.new(1), symbol, ctx)
      {:ok, hub_value, hub_mono}
    else
      _ -> :none
    end
  end

  defp align_right_to_left(left_unit, %Quantity{} = right, ctx) do
    targets = category_symbols(unit_monomial(left_unit), ctx)

    Enum.reduce(unit_monomial(right.unit), {right.value, %{}}, fn {symbol, exponent},
                                                                  {value, acc} ->
      case overlapping_symbol(symbol, targets, ctx) do
        {:ok, target} when target != symbol ->
          factor = convert_to(%Quantity{value: Decimal.new(1), unit: symbol}, target, ctx)
          scaled = Decimal.mult(value, integer_pow(factor, exponent))
          {scaled, combine_monomials(acc, %{target => exponent})}

        _ ->
          {value, combine_monomials(acc, %{symbol => exponent})}
      end
    end)
  end

  defp category_symbols(monomial, ctx) do
    Enum.reduce(monomial, %{}, fn {symbol, _exponent}, acc ->
      case Catalog.category_for_unit(ctx.units, symbol) do
        {:ok, category} -> Map.put_new(acc, category, symbol)
        :error -> acc
      end
    end)
  end

  defp overlapping_symbol(symbol, targets, ctx) do
    case Catalog.category_for_unit(ctx.units, symbol) do
      {:ok, category} -> Map.fetch(targets, category)
      :error -> :error
    end
  end

  defp quantity_or_decimal(value, monomial) when map_size(monomial) == 0, do: value
  defp quantity_or_decimal(value, monomial), do: quantity(value, Unit.from_monomial(monomial))

  defp same_category_units?(left, right, ctx) do
    case {unit_dim(left, ctx), unit_dim(right, ctx)} do
      {{:ok, dim}, {:ok, dim}} -> true
      _ -> false
    end
  end

  defp unit_dim(unit, ctx) do
    formula_target_dim(unit_monomial(unit), ctx.units)
  end

  defp unit_monomial(%Unit{monomial: monomial}), do: monomial

  defp unit_monomial(unit) when is_binary(unit) do
    case Formula.parse(unit) do
      {:ok, monomial} -> monomial
      {:error, _} -> %{unit => 1}
    end
  end

  defp unit_monomial(unit) when is_map(unit), do: unit

  defp invert_monomial(monomial) do
    Map.new(monomial, fn {symbol, exponent} -> {symbol, -exponent} end)
  end

  defp combine_monomials(left, right) do
    left
    |> Map.merge(right, fn _symbol, a, b -> a + b end)
    |> Map.reject(fn {_symbol, exponent} -> exponent == 0 end)
  end

  defp monomial_to_base_hub(value, monomial, ctx) do
    Enum.reduce(monomial, {value, %{}}, fn {symbol, exponent}, {acc_value, acc_mono} ->
      {hub_value, hub_mono} = named_to_base_hub(Decimal.new(1), symbol, ctx)
      scaled = Decimal.mult(acc_value, integer_pow(hub_value, exponent))
      {scaled, combine_monomials(acc_mono, scale_monomial(hub_mono, exponent))}
    end)
  end

  defp scale_monomial(monomial, exponent) do
    monomial
    |> Map.new(fn {symbol, n} -> {symbol, n * exponent} end)
    |> Map.reject(fn {_symbol, n} -> n == 0 end)
  end

  defp scale_dim(dim, exponent) do
    dim
    |> Map.new(fn {category, n} -> {category, n * exponent} end)
    |> Map.reject(fn {_category, n} -> n == 0 end)
  end

  defp integer_pow(_base, 0), do: Decimal.new(1)
  defp integer_pow(base, 1), do: base

  defp integer_pow(base, exponent) when exponent > 1 do
    Enum.reduce(2..exponent, base, fn _, acc -> Decimal.mult(acc, base) end)
  end

  defp integer_pow(base, exponent) when exponent < 0 do
    Decimal.div(Decimal.new(1), integer_pow(base, -exponent))
  end

  defp convert_to(%Quantity{value: value, unit: from_unit}, to_unit, ctx) do
    from_name = registered_name(from_unit)
    to_name = registered_name(to_unit)

    cond do
      unit_monomial(from_unit) == unit_monomial(to_unit) ->
        value

      is_binary(from_name) and is_binary(to_name) and
          same_named_category?(from_name, to_name, ctx) ->
        convert_named(value, from_name, to_name, ctx)

      true ->
        convert_via_base_hub(value, from_unit, to_unit, ctx)
    end
  end

  defp same_named_category?(from_name, to_name, ctx) do
    case {Catalog.category_for_unit(ctx.units, from_name),
          Catalog.category_for_unit(ctx.units, to_name)} do
      {{:ok, category}, {:ok, category}} -> true
      _ -> false
    end
  end

  defp convert_via_base_hub(value, from_unit, to_unit, ctx) do
    {from_value, from_hub} = to_base_hub(value, from_unit, ctx)
    {to_factor, to_hub} = to_base_hub(Decimal.new(1), to_unit, ctx)

    if from_hub == to_hub do
      Decimal.div(from_value, to_factor)
    else
      raise hub_mismatch_message(from_unit, to_unit, ctx)
    end
  end

  defp hub_mismatch_message(from_unit, to_unit, _ctx) do
    "cannot convert #{unit_formula(from_unit)} to #{unit_formula(to_unit)}"
  end

  defp unit_formula(unit) do
    unit
    |> to_unit()
    |> inspect()
    |> String.replace_prefix("#Elex.Unit<", "")
    |> String.replace_suffix(">", "")
  end

  defp result_kind(%Decimal{}), do: label(:decimal)
  defp result_kind(value) when is_boolean(value), do: label(:boolean)
  defp result_kind(value) when is_binary(value), do: label(:string)
  defp result_kind(nil), do: label(nil)
  defp result_kind(_value), do: label(:unknown)

  defp to_base_hub(value, unit, ctx) do
    monomial = unit_monomial(unit)

    case named_hub_symbol(unit, monomial) do
      name when is_binary(name) -> named_to_base_hub(value, name, ctx)
      nil -> monomial_to_base_hub(value, monomial, ctx)
    end
  end

  defp named_hub_symbol(unit, monomial) do
    case registered_name(unit) do
      name when is_binary(name) ->
        if monomial == %{name => 1}, do: name, else: nil

      _ ->
        nil
    end
  end

  defp named_to_base_hub(value, name, ctx) do
    {:ok, category} = Catalog.category_for_unit(ctx.units, name)
    default = Catalog.categories(ctx.units)[category]
    in_default = convert_named_or_same(value, name, default, ctx)

    case Catalog.formula_identity(ctx.units, category) do
      {identity_name, identity_monomial} ->
        in_identity = convert_hub_to_identity(in_default, default, identity_name, ctx)
        monomial_to_base_hub(in_identity, identity_monomial, ctx)

      nil ->
        {in_default, %{default => 1}}
    end
  end

  defp convert_hub_to_identity(value, default, identity_name, ctx) do
    case Catalog.fetch_unit(ctx.units, identity_name) do
      {:ok, _} -> convert_named_or_same(value, default, identity_name, ctx)
      :error -> value
    end
  end

  defp convert_named_or_same(value, from_name, to_name, _ctx) when from_name == to_name, do: value

  defp convert_named_or_same(value, from_name, to_name, ctx) do
    convert_named(value, from_name, to_name, ctx)
  end

  defp convert_named(value, from_unit, to_unit, ctx) do
    from_entry = fetch_unit!(ctx.units, from_unit)
    to_entry = fetch_unit!(ctx.units, to_unit)
    in_default = evaluate!(from_entry.to_default_ast, conversion_context(value))
    evaluate!(to_entry.from_default_ast, conversion_context(in_default))
  end

  defp quantity(value, unit), do: %Quantity{value: value, unit: to_unit(unit)}

  defp to_unit(%Unit{} = unit), do: unit
  defp to_unit(symbol) when is_binary(symbol), do: Unit.new!(symbol)
  defp to_unit(monomial) when is_map(monomial), do: Unit.from_monomial(monomial)

  defp registered_unit(name), do: Unit.new!(name)

  defp result_unit(name, %{units: %Catalog{} = catalog}) do
    case Catalog.canonical_name(catalog, name) do
      {:ok, canonical} -> Unit.new!(canonical)
      :error -> formula_result_unit(name, catalog)
    end
  end

  defp result_unit(name, _ctx), do: Unit.new!(name)

  defp formula_result_unit(name, catalog) do
    case Catalog.parse_formula(catalog, name) do
      {:ok, monomial} -> Unit.from_monomial(monomial)
      {:error, _} -> Unit.new!(name)
    end
  end

  defp registered_name(%Unit{monomial: monomial}) do
    case Enum.to_list(monomial) do
      [{symbol, 1}] -> symbol
      _ -> nil
    end
  end

  defp registered_name(symbol) when is_binary(symbol), do: symbol
  defp registered_name(_unit), do: nil

  defp fetch_unit!(catalog, name) do
    case Catalog.fetch_unit(catalog, name) do
      {:ok, entry} -> entry
      :error -> raise "unknown unit '#{name}'"
    end
  end

  defp conversion_context(value) do
    Elex.new_context() |> Elex.add_variable!("value", value)
  end

  defp to_decimal(%Decimal{} = decimal), do: decimal
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n)

  defp humanize_decimal_error(%Decimal.Error{} = error) do
    error |> Exception.message() |> String.replace("_", " ")
  end
end
