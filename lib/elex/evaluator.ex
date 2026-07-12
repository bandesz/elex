defmodule Elex.Evaluator do
  @moduledoc """
  Evaluates a parsed expression AST to a runtime value.

  This module raises `RuntimeError` on evaluation failures (missing variables, type
  errors, function failures). For a safe string-based API that returns error tuples,
  prefer `Elex.evaluate/2`.

  ## Examples

      context = Elex.new_context() |> Elex.add_variable("x", 10)
      {:ok, ast, _} = Elex.Parser.parse("x + 5", context)
      Elex.Evaluator.evaluate(ast, context)
      #=> #Decimal<15>

  """
  alias Elex.Context
  import Elex.Labels

  @doc """
  Evaluates a parsed expression AST.

  ## Parameters

  - `ast` - A parsed AST node from [`Elex.Parser`](Elex.Parser)
  - `ctx` - A [`Elex.Context`](Elex.Context) with variable values and functions

  ## Returns

  The evaluated result: a `Decimal.t()`, `boolean()`, or `String.t()`.

  ## Raises

  - `RuntimeError` on type errors, missing variables, or function call failures

  ## Examples

      context = Elex.new_context() |> Elex.add_variable("x", 10)
      {:ok, ast, _} = Elex.Parser.parse("x * 2", context)
      Elex.Evaluator.evaluate(ast, context)
      #=> #Decimal<20>

  """
  @spec evaluate(term(), Context.t()) :: Decimal.t() | boolean() | any()
  def evaluate(ast, ctx)

  def evaluate(%Decimal{} = decimal, _ctx), do: decimal

  def evaluate(val, _ctx) when is_boolean(val), do: val

  def evaluate(val, _ctx) when is_binary(val), do: val

  def evaluate(nil, _ctx), do: nil

  def evaluate({:not, ast}, ctx) do
    case evaluate(ast, ctx) do
      v when is_boolean(v) ->
        !v

      _ ->
        raise("not operator can only be used with #{label(:boolean)} values")
    end
  end

  def evaluate({:-, ast}, ctx) when not is_list(ast) do
    case evaluate(ast, ctx) do
      %Decimal{} = decimal ->
        Decimal.negate(decimal)

      _ ->
        raise("- operator can only be used with #{label(:decimal)} values")
    end
  end

  def evaluate({:+, [left_ast, right_ast]}, ctx) do
    Decimal.add(evaluate(left_ast, ctx), evaluate(right_ast, ctx))
  end

  def evaluate({:-, [left_ast, right_ast]}, ctx) do
    Decimal.add(evaluate(left_ast, ctx), Decimal.negate(evaluate(right_ast, ctx)))
  end

  def evaluate({:*, [left_ast, right_ast]}, ctx) do
    Decimal.mult(evaluate(left_ast, ctx), evaluate(right_ast, ctx))
  end

  def evaluate({:/, [left_ast, right_ast]}, ctx) do
    Decimal.div(evaluate(left_ast, ctx), evaluate(right_ast, ctx))
  end

  def evaluate({:%, [left_ast, right_ast]}, ctx) do
    Decimal.rem(evaluate(left_ast, ctx), evaluate(right_ast, ctx))
  end

  def evaluate({:<, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)

    case {left, right} do
      {%Decimal{}, %Decimal{}} -> Decimal.compare(left, right) == :lt
      {left, right} when is_binary(left) and is_binary(right) -> left < right
    end
  end

  def evaluate({:>, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)

    case {left, right} do
      {%Decimal{}, %Decimal{}} -> Decimal.compare(left, right) == :gt
      {left, right} when is_binary(left) and is_binary(right) -> left > right
    end
  end

  def evaluate({:<=, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)

    case {left, right} do
      {%Decimal{}, %Decimal{}} ->
        case Decimal.compare(left, right) do
          :lt -> true
          :eq -> true
          :gt -> false
        end

      {left, right} when is_binary(left) and is_binary(right) ->
        left <= right
    end
  end

  def evaluate({:>=, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)

    case {left, right} do
      {%Decimal{}, %Decimal{}} ->
        case Decimal.compare(left, right) do
          :gt -> true
          :eq -> true
          :lt -> false
        end

      {left, right} when is_binary(left) and is_binary(right) ->
        left >= right
    end
  end

  def evaluate({:==, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)

    case {left, right} do
      {%Decimal{}, %Decimal{}} -> Decimal.compare(left, right) == :eq
      {_, _} -> left == right
    end
  end

  def evaluate({:!=, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)

    case {left, right} do
      {%Decimal{}, %Decimal{}} -> Decimal.compare(left, right) != :eq
      {_, _} -> left != right
    end
  end

  def evaluate({:and, [left_ast, right_ast]}, ctx) do
    case evaluate(left_ast, ctx) do
      false -> false
      true -> evaluate(right_ast, ctx)
    end
  end

  def evaluate({:or, [left_ast, right_ast]}, ctx) do
    case evaluate(left_ast, ctx) do
      true -> true
      false -> evaluate(right_ast, ctx)
    end
  end

  def evaluate({:var, name}, ctx) do
    variable = Map.fetch!(ctx.variables, name)
    variable.value
  end

  def evaluate({:func, "if", 3, [cond_ast, true_ast, false_ast]}, ctx) do
    if evaluate(cond_ast, ctx) do
      evaluate(true_ast, ctx)
    else
      evaluate(false_ast, ctx)
    end
  end

  def evaluate({:func, name, arity, args_ast}, ctx) do
    function_module = lookup_function!(ctx, name, arity)
    evaluated_args = Enum.map(args_ast, &evaluate(&1, ctx))

    case function_module.call(evaluated_args) do
      {:ok, result} ->
        result

      {:error, reason} ->
        raise "Error calling function #{name}/#{arity}: #{inspect(reason)}"
    end
  end

  defp lookup_function!(ctx, name, arity) do
    case Map.fetch(ctx.functions, {name, arity}) do
      {:ok, function_module} ->
        function_module

      :error ->
        case Map.fetch(ctx.functions, {name, :variadic}) do
          {:ok, function_module} ->
            min_arity = function_module.signature().min_arity

            if arity >= min_arity do
              function_module
            else
              raise "Function #{name}/#{arity} not found"
            end

          :error ->
            raise "Function #{name}/#{arity} not found"
        end
    end
  end
end
