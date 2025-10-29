defmodule Elex.Evaluator do
  alias Elex.Context
  import Elex.Labels

  @spec evaluate(term(), Context.t()) :: Decimal.t() | boolean() | any()
  def evaluate(ast, ctx)

  def evaluate(%Decimal{} = decimal, _ctx), do: decimal

  def evaluate(val, _ctx) when is_boolean(val), do: val

  def evaluate(val, _ctx) when is_binary(val), do: val

  def evaluate({:not, ast}, ctx) do
    case evaluate(ast, ctx) do
      v when is_boolean(v) ->
        !v

      _ ->
        raise("not operator can only be used with #{label(:boolean)} values")
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

  def evaluate({:<, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)
    Decimal.compare(left, right) == :lt
  end

  def evaluate({:>, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)
    Decimal.compare(left, right) == :gt
  end

  def evaluate({:<=, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)

    case Decimal.compare(left, right) do
      :lt -> true
      :eq -> true
      :gt -> false
    end
  end

  def evaluate({:>=, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)

    case Decimal.compare(left, right) do
      :gt -> true
      :eq -> true
      :lt -> false
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
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)
    left && right
  end

  def evaluate({:or, [left_ast, right_ast]}, ctx) do
    left = evaluate(left_ast, ctx)
    right = evaluate(right_ast, ctx)
    left || right
  end

  def evaluate({:var, name}, ctx) do
    variable = Map.fetch!(ctx.variables, name)
    variable.value
  end

  def evaluate({:func, name, arity, args_ast}, ctx) do
    function_module = Map.fetch!(ctx.functions, {name, arity})
    evaluated_args = Enum.map(args_ast, &evaluate(&1, ctx))

    case function_module.call(evaluated_args) do
      {:ok, result} ->
        result

      {:error, reason} ->
        raise "Error calling function #{name}/#{arity}: #{inspect(reason)}"
    end
  end
end
