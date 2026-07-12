defmodule Elex.Parser.ErrorFormatter do
  @moduledoc """
  Translates low-level parser failures into human-readable error messages.

  The underlying NimbleParsec parser reports failures in terms of the grammar
  combinators it tried (for example `"expected end of string"`). Those messages
  are meaningless to someone writing an expression, so this module inspects the
  original input together with the unconsumed remainder and produces a short,
  plain-English description of what went wrong.

  It is used by [`Elex.Parser.parse/3`](`Elex.Parser.parse/3`); most callers do
  not need to use it directly.
  """

  @two_char_operators ~w(<= >= == !=)
  @one_char_operators ~w(+ - * / % < >)
  @word_operators ~w(and or)
  @reserved_operators ~w(and or not)

  @doc """
  Builds a human-readable message for a parser failure.

  ## Parameters

  - `expression` - the original expression string that failed to parse
  - `rest` - the unconsumed remainder reported by the parser at the furthest
    position it reached
  - `byte_offset` - the byte offset of that position into `expression`

  ## Examples

      iex> Elex.Parser.ErrorFormatter.humanize("( 1 + 2", "( 1 + 2", 0)
      "closing parenthesis is missing"

      iex> Elex.Parser.ErrorFormatter.humanize("1 +", "+", 2)
      "a value is missing after '+'"

      iex> Elex.Parser.ErrorFormatter.humanize("max(1 2)", "2)", 6)
      "arguments must be separated by commas"

  """
  @spec humanize(String.t(), String.t(), non_neg_integer()) :: String.t()
  def humanize(expression, rest, byte_offset) do
    if blank?(expression) do
      "the expression is empty"
    else
      case scan_structure(expression) do
        {:error, message} -> message
        :ok -> token_message(expression, rest, byte_offset)
      end
    end
  end

  # Scans the whole input for unbalanced parentheses and unterminated strings,
  # ignoring parentheses that appear inside string literals.
  defp scan_structure(expression) do
    scan(String.to_charlist(expression), 0, false)
  end

  defp scan([], _depth, true), do: {:error, "closing quote is missing"}
  defp scan([], depth, false) when depth > 0, do: {:error, "closing parenthesis is missing"}
  defp scan([], _depth, false), do: :ok

  # Inside a string literal. The parser only recognises `\"` as an escape (see
  # the `escaped_quote` combinator in `Elex.Parser`); a backslash followed by
  # anything else - or a trailing backslash - can never close the string, so we
  # report it consistently as a missing closing quote.
  defp scan([?\\, ?" | rest], depth, true), do: scan(rest, depth, true)
  defp scan([?\\ | _rest], _depth, true), do: {:error, "closing quote is missing"}
  defp scan([?" | rest], depth, true), do: scan(rest, depth, false)
  defp scan([_char | rest], depth, true), do: scan(rest, depth, true)

  # Outside a string literal.
  defp scan([?" | rest], depth, false), do: scan(rest, depth, true)
  defp scan([?( | rest], depth, false), do: scan(rest, depth + 1, false)
  defp scan([?) | _rest], 0, false), do: {:error, "unexpected closing parenthesis"}
  defp scan([?) | rest], depth, false), do: scan(rest, depth - 1, false)
  defp scan([_char | rest], depth, false), do: scan(rest, depth, false)

  defp token_message(expression, rest, byte_offset) do
    consumed = binary_part(expression, 0, byte_offset)
    remainder = String.trim_leading(rest)

    cond do
      remainder == "" ->
        "the expression is incomplete"

      empty_parentheses?(remainder) ->
        "an expression is expected inside the parentheses"

      operator = leading_operator(remainder) ->
        operator_message(operator, consumed)

      value_start?(remainder) and open_group_kind(consumed) == :function ->
        "arguments must be separated by commas"

      true ->
        "unexpected '#{first_token(remainder)}'"
    end
  end

  defp operator_message(operator, consumed) do
    if blank?(consumed) do
      "an expression can not start with '#{operator}'"
    else
      "a value is missing after '#{operator}'"
    end
  end

  defp empty_parentheses?("(" <> rest), do: String.starts_with?(String.trim_leading(rest), ")")
  defp empty_parentheses?(_), do: false

  # True when the remainder begins with something that could start a value
  # (a number, identifier, string, or a parenthesised sub-expression). When the
  # parser stalls on such a token it means a previous value was already parsed,
  # so a separator or operator is missing between the two.
  defp value_start?(<<char::utf8, _::binary>>) do
    letter_or_underscore?(char) or digit?(char) or char in [?", ?(]
  end

  defp value_start?(_), do: false

  # Inspects the already-consumed input and reports the kind of the innermost
  # still-open parenthesis: `:function` when it follows a function name (an
  # identifier that is not a reserved operator), `:group` for a plain grouping
  # (including one led by `and`/`or`/`not`), or `:none` when no parenthesis is
  # open. Parentheses inside string literals are ignored. The preceding word is
  # tracked so `max(` is a call while `not (` is a grouping.
  defp open_group_kind(consumed) do
    consumed |> String.to_charlist() |> scan_groups(false, [], [])
  end

  defp scan_groups([], _in_string, [kind | _], _word), do: kind
  defp scan_groups([], _in_string, [], _word), do: :none

  defp scan_groups([?\\, _escaped | rest], true, stack, word),
    do: scan_groups(rest, true, stack, word)

  defp scan_groups([?" | rest], true, stack, word), do: scan_groups(rest, false, stack, word)
  defp scan_groups([_char | rest], true, stack, word), do: scan_groups(rest, true, stack, word)

  defp scan_groups([?" | rest], false, stack, _word), do: scan_groups(rest, true, stack, [])

  defp scan_groups([?( | rest], false, stack, word) do
    scan_groups(rest, false, [group_kind(word) | stack], [])
  end

  defp scan_groups([?) | rest], false, stack, _word) do
    scan_groups(rest, false, drop_top(stack), [])
  end

  defp scan_groups([char | rest], false, stack, word) do
    cond do
      identifier_char?(char) -> scan_groups(rest, false, stack, [char | word])
      char in ~c" \t" -> scan_groups(rest, false, stack, word)
      true -> scan_groups(rest, false, stack, [])
    end
  end

  defp group_kind([]), do: :group

  defp group_kind(reversed_word) do
    word = reversed_word |> Enum.reverse() |> List.to_string()
    if word in @reserved_operators, do: :group, else: :function
  end

  defp drop_top([]), do: []
  defp drop_top([_top | rest]), do: rest

  defp leading_operator(remainder) do
    word_operator(remainder) || symbol_operator(remainder)
  end

  defp word_operator(remainder) do
    Enum.find(@word_operators, fn word -> word_operator?(remainder, word) end)
  end

  defp word_operator?(remainder, word) do
    String.starts_with?(remainder, word) and word_boundary_after?(remainder, word)
  end

  defp word_boundary_after?(remainder, word) do
    case String.split_at(remainder, String.length(word)) do
      {_, ""} -> true
      {_, <<next::utf8, _::binary>>} -> not identifier_char?(next)
    end
  end

  defp symbol_operator(remainder) do
    Enum.find(@two_char_operators ++ @one_char_operators, &String.starts_with?(remainder, &1))
  end

  defp first_token(<<char::utf8, _::binary>>) when char in [?(, ?), ?,], do: <<char::utf8>>

  defp first_token(remainder) do
    cond do
      starts_with_class?(remainder, &letter_or_underscore?/1) ->
        take_while(remainder, &identifier_char?/1)

      starts_with_class?(remainder, &digit?/1) ->
        take_while(remainder, fn char -> digit?(char) or char == ?. end)

      true ->
        take_while(remainder, &symbol_char?/1)
    end
  end

  defp starts_with_class?(<<char::utf8, _::binary>>, predicate), do: predicate.(char)
  defp starts_with_class?(_, _), do: false

  defp take_while(string, predicate) do
    string
    |> String.to_charlist()
    |> Enum.take_while(predicate)
    |> List.to_string()
  end

  defp identifier_char?(char), do: letter_or_underscore?(char) or digit?(char)

  defp letter_or_underscore?(char), do: char in ?a..?z or char in ?A..?Z or char == ?_

  defp digit?(char), do: char in ?0..?9

  defp symbol_char?(char) do
    not (letter_or_underscore?(char) or digit?(char) or char in ~c" \t(),")
  end

  defp blank?(string), do: String.trim(string) == ""
end
