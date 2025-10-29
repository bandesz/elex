defmodule Elex.Inverter do
  @moduledoc """
  Inverts simple arithmetic expressions with a single variable.

  Given an expression like "value + 5", it returns the inverse "value - 5".
  This is useful for creating inverse transformations.

  Supported operations:
  - Addition (+) → Subtraction (-)
  - Subtraction (-) → Addition (+)
  - Multiplication (*) → Division (/)
  - Division (/) → Multiplication (*)

  ## Examples

      # value + 5 → value - 5
      # value * 3 → value / 3
      # 10 - value → 10 - value (constant - variable case)
      # 100 / value → 100 / value (constant / variable case)
  """

  @doc """
  Inverts an expression AST for the given target variable.

  ## Parameters

  - `ast` - The parsed expression AST
  - `target_var` - The name of the variable to solve for (string)

  ## Returns

  Returns the inverted AST that represents the inverse operation.

  ## Raises

  - `RuntimeError` if the expression contains multiple variables
  - `RuntimeError` if the target variable is not found in the expression
  - `RuntimeError` if the operation is not supported for inversion
  - `RuntimeError` if division by zero would occur
  """
  @spec invert(term(), String.t()) :: term()
  def invert(ast, target_var) do
    # First, validate that we can invert this expression
    validate_invertible(ast, target_var)

    # Then perform the inversion
    do_invert(ast, target_var)
  end

  # Validate that the expression is invertible
  defp validate_invertible(ast, target_var) do
    variables = collect_variables(ast)

    cond do
      length(variables) > 1 ->
        raise "Expression contains multiple variables: #{Enum.join(variables, ", ")}. Only single-variable expressions can be inverted."

      Enum.empty?(variables) ->
        # If no variables, it's just a literal - this is fine, we'll return it unchanged
        :ok

      target_var not in variables ->
        raise "Target variable '#{target_var}' not found in expression"

      true ->
        :ok
    end
  end

  # Collect all variable names from an AST
  defp collect_variables(ast) do
    collect_variables(ast, MapSet.new()) |> MapSet.to_list()
  end

  defp collect_variables({:var, name}, acc) do
    MapSet.put(acc, name)
  end

  defp collect_variables({op, [left, right]}, acc)
       when op in [:+, :-, :*, :/, :<, :>, :<=, :>=, :==, :!=, :and, :or] do
    acc = collect_variables(left, acc)
    collect_variables(right, acc)
  end

  defp collect_variables({:not, operand}, acc) do
    collect_variables(operand, acc)
  end

  defp collect_variables({:func, _name, _arity, args}, acc) do
    Enum.reduce(args, acc, &collect_variables(&1, &2))
  end

  defp collect_variables(_literal, acc) do
    acc
  end

  # Main inversion logic
  defp do_invert({:var, name}, target_var) when name == target_var do
    # If the expression is just the target variable, return it unchanged
    {:var, target_var}
  end

  defp do_invert(%Decimal{} = literal, _target_var) do
    # If the expression is just a decimal literal, return it unchanged
    literal
  end

  defp do_invert(literal, _target_var) when is_binary(literal) or is_boolean(literal) do
    # If the expression is just a literal (doesn't contain the variable), return it unchanged
    literal
  end

  # Algebraic equation solving: expr = result → solve for target_var
  # For expr + c = result → expr = result - c (subtract c from both sides)
  defp do_invert({:+, [left, right]}, target_var) do
    cond do
      contains_variable?(left, target_var) and not contains_variable?(right, target_var) ->
        # expr + c = result → expr = result - c
        new_right_side = {:-, [{:var, target_var}, right]}
        solve_equation(left, target_var, new_right_side)

      not contains_variable?(left, target_var) and contains_variable?(right, target_var) ->
        # c + expr = result → expr = result - c
        new_right_side = {:-, [{:var, target_var}, left]}
        solve_equation(right, target_var, new_right_side)

      true ->
        raise "Unsupported operation for inversion: addition with variable on both sides"
    end
  end

  # For expr - c = result → expr = result + c (add c to both sides)
  defp do_invert({:-, [left, right]}, target_var) do
    cond do
      contains_variable?(left, target_var) and not contains_variable?(right, target_var) ->
        # expr - c = result → expr = result + c
        new_right_side = {:+, [{:var, target_var}, right]}
        solve_equation(left, target_var, new_right_side)

      not contains_variable?(left, target_var) and contains_variable?(right, target_var) ->
        # c - expr = result → expr = c - result
        new_right_side = {:-, [left, {:var, target_var}]}
        solve_equation(right, target_var, new_right_side)

      true ->
        raise "Unsupported operation for inversion: subtraction with variable on both sides"
    end
  end

  # For expr * c = result → expr = result / c (divide both sides by c)
  defp do_invert({:*, [left, right]}, target_var) do
    cond do
      contains_variable?(left, target_var) and not contains_variable?(right, target_var) ->
        # expr * c = result → expr = result / c
        if zero?(right) do
          raise "Cannot invert: division by zero"
        end

        new_right_side = {:/, [{:var, target_var}, right]}
        solve_equation(left, target_var, new_right_side)

      not contains_variable?(left, target_var) and contains_variable?(right, target_var) ->
        # c * expr = result → expr = result / c
        if zero?(left) do
          raise "Cannot invert: division by zero"
        end

        new_right_side = {:/, [{:var, target_var}, left]}
        solve_equation(right, target_var, new_right_side)

      true ->
        raise "Unsupported operation for inversion: multiplication with variable on both sides"
    end
  end

  # For expr / c = result → expr = result * c (multiply both sides by c)
  defp do_invert({:/, [left, right]}, target_var) do
    cond do
      contains_variable?(left, target_var) and not contains_variable?(right, target_var) ->
        # expr / c = result → expr = result * c
        new_right_side = {:*, [{:var, target_var}, right]}
        solve_equation(left, target_var, new_right_side)

      not contains_variable?(left, target_var) and contains_variable?(right, target_var) ->
        # c / expr = result → expr = c / result
        new_right_side = {:/, [left, {:var, target_var}]}
        solve_equation(right, target_var, new_right_side)

      true ->
        raise "Unsupported operation for inversion: division with variable on both sides"
    end
  end

  # Handle nested expressions by recursively inverting them
  # For complex expressions like (value * 2) + 3, we need to apply inverse operations in reverse order
  defp do_invert(other, _target_var) do
    raise "Unsupported operation for inversion: #{inspect(other)}"
  end

  # Recursive equation solver: continues until left_side is just the target variable
  defp solve_equation({:var, name}, target_var, right_side) when name == target_var do
    # Base case: we have target_var = right_side, so return the right side
    right_side
  end

  defp solve_equation(left_side, target_var, right_side) do
    # Recursive case: apply another transformation to isolate the target variable
    # Replace {:var, target_var} in the inverted left_side with the current right_side
    inverted_left = do_invert(left_side, target_var)
    replace_target_var(inverted_left, target_var, right_side)
  end

  # Helper to replace target variable with the right-hand side expression
  defp replace_target_var({:var, name}, target_var, replacement) when name == target_var do
    replacement
  end

  defp replace_target_var({op, [left, right]}, target_var, replacement)
       when op in [:+, :-, :*, :/, :<, :>, :<=, :>=, :==, :!=, :and, :or] do
    {op,
     [
       replace_target_var(left, target_var, replacement),
       replace_target_var(right, target_var, replacement)
     ]}
  end

  defp replace_target_var({:not, operand}, target_var, replacement) do
    {:not, replace_target_var(operand, target_var, replacement)}
  end

  defp replace_target_var({:func, name, arity, args}, target_var, replacement) do
    {:func, name, arity, Enum.map(args, &replace_target_var(&1, target_var, replacement))}
  end

  defp replace_target_var(literal, _target_var, _replacement) do
    literal
  end

  # Helper function to check if an AST contains the target variable
  defp contains_variable?({:var, name}, target_var) do
    name == target_var
  end

  defp contains_variable?({op, [left, right]}, target_var)
       when op in [:+, :-, :*, :/, :<, :>, :<=, :>=, :==, :!=, :and, :or] do
    contains_variable?(left, target_var) or contains_variable?(right, target_var)
  end

  defp contains_variable?({:not, operand}, target_var) do
    contains_variable?(operand, target_var)
  end

  defp contains_variable?({:func, _name, _arity, args}, target_var) do
    Enum.any?(args, &contains_variable?(&1, target_var))
  end

  defp contains_variable?(_literal, _target_var) do
    false
  end

  # Helper function to check if a value is zero
  defp zero?(%Decimal{} = d) do
    Decimal.equal?(d, Decimal.new("0"))
  end

  defp zero?(0), do: true
  defp zero?(+0.0), do: true
  defp zero?(-0.0), do: true
  defp zero?(_), do: false
end
