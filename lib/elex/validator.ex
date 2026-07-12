defmodule Elex.Validator do
  @moduledoc """
  Validates a parsed expression AST for type correctness.

  Checks that operators are applied to compatible types, variables exist in the
  context, and function calls match registered signatures. Used by
  [`Elex.Parser`](Elex.Parser) during parsing and available for direct AST validation.

  ## Examples

      context = Elex.new_context() |> Elex.add_variable("x", 10)
      {:ok, ast, _} = Elex.Parser.parse("x + 5", context, validate: false)
      Elex.Validator.validate(ast, context)
      #=> {:ok, :decimal}

  """
  alias Elex.Context
  import Elex.Labels

  @reserved_keywords ["and", "or", "not"]

  @doc """
  Validates an expression AST against a context.

  ## Parameters

  - `ast` - A parsed AST node from [`Elex.Parser`](Elex.Parser)
  - `ctx` - A [`Elex.Context`](Elex.Context) with variable types and functions

  ## Returns

  - `{:ok, type}` - The expression's result type (`:decimal`, `:boolean`, or `:string`)
  - `{:error, reason}` - A human-readable validation error

  ## Examples

      context = Elex.new_context() |> Elex.add_variable("x", 10)
      {:ok, ast, _} = Elex.Parser.parse("x > 0", context, validate: false)
      Elex.Validator.validate(ast, context)
      #=> {:ok, :boolean}

  """
  @spec validate(term(), Context.t()) ::
          {:ok, atom()} | {:error, String.t()}
  def validate(ast, ctx)

  def validate(%Decimal{}, _ctx), do: {:ok, :decimal}

  def validate(val, _ctx) when is_boolean(val), do: {:ok, :boolean}

  def validate(val, _ctx) when is_binary(val), do: {:ok, :string}

  def validate({:not, ast}, ctx) do
    case validate(ast, ctx) do
      {:ok, :boolean} ->
        {:ok, :boolean}

      {:ok, type} ->
        {:error, "not operator can not be used on #{label(type)} value"}

      {:error, err} ->
        {:error, err}
    end
  end

  def validate({:-, ast}, ctx) when not is_list(ast) do
    case validate(ast, ctx) do
      {:ok, :decimal} ->
        {:ok, :decimal}

      {:ok, type} ->
        {:error, "- operator can not be used on #{label(type)} value"}

      {:error, err} ->
        {:error, err}
    end
  end

  def validate({:+, [left_ast, right_ast]}, ctx) do
    validate_decimal_op(:+, left_ast, right_ast, ctx)
  end

  def validate({:-, [left_ast, right_ast]}, ctx) do
    validate_decimal_op(:-, left_ast, right_ast, ctx)
  end

  def validate({:*, [left_ast, right_ast]}, ctx) do
    validate_decimal_op(:*, left_ast, right_ast, ctx)
  end

  def validate({:/, [left_ast, right_ast]}, ctx) do
    validate_decimal_op(:/, left_ast, right_ast, ctx)
  end

  def validate({:%, [left_ast, right_ast]}, ctx) do
    validate_decimal_op(:%, left_ast, right_ast, ctx)
  end

  def validate({:<, [left_ast, right_ast]}, ctx) do
    validate_comparison_op(:<, left_ast, right_ast, ctx)
  end

  def validate({:>, [left_ast, right_ast]}, ctx) do
    validate_comparison_op(:>, left_ast, right_ast, ctx)
  end

  def validate({:<=, [left_ast, right_ast]}, ctx) do
    validate_comparison_op(:<=, left_ast, right_ast, ctx)
  end

  def validate({:>=, [left_ast, right_ast]}, ctx) do
    validate_comparison_op(:>=, left_ast, right_ast, ctx)
  end

  def validate({:==, [left_ast, right_ast]}, ctx) do
    validate_equality_op(:==, left_ast, right_ast, ctx)
  end

  def validate({:!=, [left_ast, right_ast]}, ctx) do
    validate_equality_op(:!=, left_ast, right_ast, ctx)
  end

  def validate({:and, [left_ast, right_ast]}, ctx) do
    validate_boolean_op(:and, left_ast, right_ast, ctx)
  end

  def validate({:or, [left_ast, right_ast]}, ctx) do
    validate_boolean_op(:or, left_ast, right_ast, ctx)
  end

  def validate({:var, name}, ctx) do
    if name not in @reserved_keywords do
      case Map.fetch(ctx.variables, name) do
        {:ok, variable} -> {:ok, variable.type}
        :error -> {:error, "variable '#{name}' does not exist"}
      end
    else
      {:error, "variable '#{name}' is a reserved keyword"}
    end
  end

  def validate({:func, name, arity, args_ast}, ctx) do
    case Map.fetch(ctx.functions, {name, arity}) do
      {:ok, function_module} ->
        function_module.validate(args_ast, ctx)

      :error ->
        arities =
          Enum.filter(ctx.functions, fn {{fun, _arity}, _} -> fun == name end)
          |> Enum.map(fn {{_fun, arity}, _} -> arity end)
          |> Enum.sort()

        build_function_error(name, arity, arities)
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
    case [validate(a, ctx), validate(b, ctx)] do
      [{:ok, :decimal}, {:ok, :decimal}] ->
        {:ok, :decimal}

      [{:ok, type1}, {:ok, type2}] ->
        {:error, "'#{op}' operator can not be used on #{label(type1)} and #{label(type2)}"}

      [{:error, err}, _] ->
        {:error, err}

      [_, {:error, err}] ->
        {:error, err}
    end
  end

  defp validate_comparison_op(op, a, b, ctx) do
    case [validate(a, ctx), validate(b, ctx)] do
      [{:ok, :decimal}, {:ok, :decimal}] ->
        {:ok, :boolean}

      [{:ok, type1}, {:ok, type2}] ->
        {:error, "'#{op}' operator can not be used on #{label(type1)} and #{label(type2)}"}

      [{:error, err}, _] ->
        {:error, err}

      [_, {:error, err}] ->
        {:error, err}
    end
  end

  defp validate_equality_op(op, a, b, ctx) do
    case [validate(a, ctx), validate(b, ctx)] do
      [{:ok, type1}, {:ok, type2}]
      when type1 == type2 and type1 in [:decimal, :boolean, :string] ->
        {:ok, :boolean}

      [{:ok, type1}, {:ok, type2}] ->
        {:error, "'#{op}' operator can not be used on #{label(type1)} and #{label(type2)}"}

      [{:error, err}, _] ->
        {:error, err}

      [_, {:error, err}] ->
        {:error, err}
    end
  end

  defp validate_boolean_op(op, a, b, ctx) do
    case [validate(a, ctx), validate(b, ctx)] do
      [{:ok, :boolean}, {:ok, :boolean}] ->
        {:ok, :boolean}

      [{:ok, type1}, {:ok, type2}] ->
        {:error, "'#{op}' operator can not be used on #{label(type1)} and #{label(type2)}"}

      [{:error, err}, _] ->
        {:error, err}

      [_, {:error, err}] ->
        {:error, err}
    end
  end
end
