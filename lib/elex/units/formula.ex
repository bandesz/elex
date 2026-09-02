defmodule Elex.Units.Formula do
  @moduledoc """
  Parses unit formulas such as `m * m`, `kg * m | s^2`, and `m | s^2`.

  Formula language is not the expression language. Multiply with `*`, middot
  (`·` U+00B7 or `⋅` U+22C5), or whitespace (`kg m` is `kg * m`; `ms` is the
  symbol `ms`). At most one `|` (left numerator, right denominator). `/` and
  parentheses are invalid.   Integer `^` binds tighter than multiplication. The
  exponent must be a non-zero integer literal without a leading zero, not a
  unit. A formula that cancels to nothing (`m | m`, `m^0`) is invalid. Trailing
  digits in a symbol are part of the name (`s2` is not `s^2`). Inverse is
  `s^-1` or `1 | s` (not `| s`). `/` is invalid (`m | s`, not `m / s`).
  Braces are only a quantity suffix (`1 {m | s}`), not a formula string.

  Used when registering derived-category units and when converting an evaluate
  result to a compound `unit:` target. Callers typically write formula strings
  and do not invoke this module directly.
  """

  @type monomial :: %{optional(String.t()) => integer()}

  @spec parse(String.t()) :: {:ok, monomial()} | {:error, String.t()}
  def parse(source) when is_binary(source) do
    with {:ok, tokens} <- tokenize(source),
         {:ok, ast} <- parse_formula(tokens),
         {:ok, monomial} <- nonempty_monomial(ast) do
      {:ok, monomial}
    else
      {:error, _reason} -> {:error, invalid_formula_message(source)}
    end
  end

  @doc false
  @spec numerator_and_denominator(String.t()) ::
          {:ok, MapSet.t(String.t()), MapSet.t(String.t())} | {:error, String.t()}
  def numerator_and_denominator(source) when is_binary(source) do
    with {:ok, tokens} <- tokenize(source),
         {:ok, ast} <- parse_formula(tokens) do
      {num, den} = collect_parts(ast, 1, {[], []})
      {:ok, MapSet.new(num), MapSet.new(den)}
    else
      {:error, _reason} -> {:error, invalid_formula_message(source)}
    end
  end

  defp invalid_formula_message(source) do
    cond do
      String.contains?(source, "/") ->
        "invalid formula '#{source}'; use '|' for division (m | s, km | h), not '/'"

      String.contains?(source, "{") or String.contains?(source, "}") ->
        "invalid formula '#{source}'; braces belong on a quantity suffix (1 {m | s}), not in unit: or convert"

      true ->
        "invalid formula '#{source}'"
    end
  end

  defp tokenize(source) do
    source
    |> String.to_charlist()
    |> read_tokens([])
  end

  defp read_tokens([], acc), do: {:ok, Enum.reverse(acc)}

  defp read_tokens([char | rest], acc) when char in [?\s, ?\t], do: read_tokens(rest, acc)

  defp read_tokens([?* | rest], acc), do: read_tokens(rest, [:mul | acc])
  defp read_tokens([?· | rest], acc), do: read_tokens(rest, [:mul | acc])
  defp read_tokens([?⋅ | rest], acc), do: read_tokens(rest, [:mul | acc])
  defp read_tokens([?| | rest], acc), do: read_tokens(rest, [:pipe | acc])
  defp read_tokens([?^ | rest], acc), do: read_tokens(rest, [:pow | acc])
  defp read_tokens([?- | rest], acc), do: read_tokens(rest, [:minus | acc])

  defp read_tokens([char | rest], acc) when char in ?A..?Z or char in ?a..?z do
    {ident, rest} = read_ident(rest, [char])
    read_tokens(rest, [{:ident, ident} | acc])
  end

  defp read_tokens([?0, digit | _rest], _acc) when digit in ?0..?9 do
    {:error, "invalid formula"}
  end

  defp read_tokens([char | rest], acc) when char in ?0..?9 do
    {int, rest} = read_int(rest, [char])
    read_tokens(rest, [{:int, int} | acc])
  end

  defp read_tokens(_chars, _acc), do: {:error, "invalid formula"}

  defp read_ident([char | rest], acc)
       when char in ?A..?Z or char in ?a..?z or char in ?0..?9 or char == ?_ do
    read_ident(rest, [char | acc])
  end

  defp read_ident(rest, acc) do
    {acc |> Enum.reverse() |> List.to_string(), rest}
  end

  defp read_int([char | rest], acc) when char in ?0..?9 do
    read_int(rest, [char | acc])
  end

  defp read_int(rest, acc) do
    {acc |> Enum.reverse() |> List.to_integer(), rest}
  end

  defp parse_formula([{:int, 1}, :pipe | rest]) do
    case parse_product(rest) do
      {:ok, denominator, []} -> {:ok, {:div, :one, denominator}}
      {:ok, _denominator, _rest} -> {:error, "invalid formula"}
      {:error, _reason} = error -> error
    end
  end

  defp parse_formula(tokens) do
    with {:ok, numerator, rest} <- parse_product(tokens) do
      parse_denominator(numerator, rest)
    end
  end

  defp parse_denominator(numerator, [:pipe | rest]) do
    case parse_product(rest) do
      {:ok, denominator, []} -> {:ok, {:div, numerator, denominator}}
      {:ok, _denominator, _rest} -> {:error, "invalid formula"}
      {:error, _reason} = error -> error
    end
  end

  defp parse_denominator(numerator, []), do: {:ok, numerator}
  defp parse_denominator(_numerator, _rest), do: {:error, "invalid formula"}

  defp parse_product(tokens) do
    with {:ok, left, rest} <- parse_factor(tokens) do
      parse_product_rest(left, rest)
    end
  end

  defp parse_product_rest(left, [:mul | rest]) do
    with {:ok, right, rest} <- parse_factor(rest) do
      parse_product_rest({:mul, left, right}, rest)
    end
  end

  defp parse_product_rest(left, [{:ident, _name} | _rest] = rest) do
    with {:ok, right, rest} <- parse_factor(rest) do
      parse_product_rest({:mul, left, right}, rest)
    end
  end

  defp parse_product_rest(left, rest), do: {:ok, left, rest}

  defp parse_factor(tokens) do
    with {:ok, base, rest} <- parse_symbol(tokens) do
      case rest do
        [:pow | rest] ->
          with {:ok, exponent, rest} <- parse_exponent(rest) do
            {:ok, {:pow, base, exponent}, rest}
          end

        _ ->
          {:ok, base, rest}
      end
    end
  end

  defp parse_exponent([{:int, n} | rest]) when n != 0, do: {:ok, n, rest}
  defp parse_exponent([:minus, {:int, n} | rest]) when n != 0, do: {:ok, -n, rest}
  defp parse_exponent(_tokens), do: {:error, "invalid formula"}

  defp parse_symbol([{:ident, name} | rest]), do: {:ok, {:ident, name}, rest}
  defp parse_symbol([]), do: {:error, :empty}
  defp parse_symbol(_tokens), do: {:error, "invalid formula"}

  defp monomial(:one), do: %{}

  defp monomial({:ident, name}) do
    %{name => 1}
  end

  defp monomial({:mul, left, right}) do
    combine(monomial(left), monomial(right))
  end

  defp monomial({:div, left, right}) do
    combine(monomial(left), invert(monomial(right)))
  end

  defp monomial({:pow, base, exponent}) do
    scale(monomial(base), exponent)
  end

  defp nonempty_monomial(ast) do
    case monomial(ast) do
      monomial when map_size(monomial) == 0 -> {:error, "empty formula"}
      monomial -> {:ok, monomial}
    end
  end

  defp collect_parts(:one, _sign, acc), do: acc

  defp collect_parts({:ident, name}, sign, {num, den}) when sign > 0 do
    {[name | num], den}
  end

  defp collect_parts({:ident, name}, sign, {num, den}) when sign < 0 do
    {num, [name | den]}
  end

  defp collect_parts({:ident, _name}, 0, acc), do: acc

  defp collect_parts({:pow, base, exponent}, sign, acc) do
    collect_parts(base, sign * exponent, acc)
  end

  defp collect_parts({:mul, left, right}, sign, acc) do
    acc = collect_parts(left, sign, acc)
    collect_parts(right, sign, acc)
  end

  defp collect_parts({:div, left, right}, sign, acc) do
    acc = collect_parts(left, sign, acc)
    collect_parts(right, -sign, acc)
  end

  defp invert(monomial) do
    Map.new(monomial, fn {name, exponent} -> {name, -exponent} end)
  end

  defp scale(monomial, factor) do
    monomial
    |> Map.new(fn {name, exponent} -> {name, exponent * factor} end)
    |> Enum.reject(fn {_name, exponent} -> exponent == 0 end)
    |> Map.new()
  end

  defp combine(left, right) do
    left
    |> Map.merge(right, fn _name, a, b -> a + b end)
    |> Enum.reject(fn {_name, exponent} -> exponent == 0 end)
    |> Map.new()
  end
end
