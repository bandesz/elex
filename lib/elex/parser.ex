defmodule Elex.Parser do
  @moduledoc """
  Parses Elex expression strings into AST tuples.

  The parser is built with NimbleParsec and supports operator precedence, function calls,
  literals, and variables. Parsing optionally validates the AST against a
  [`Elex.Context`](Elex.Context) via [`Elex.Validator`](Elex.Validator).

  ## Syntax overview

  **Literals:** decimal numbers (`3.14`, `-5`), booleans (`true`, `false`, `yes`, `no`),
  null (`null`), strings (`"hello"`) with backslash escapes (`\"`, `\\`, `\n`, `\t`,
  `\r`, `\f`, `\b` — see the [Expression Language guide](expression-language.html))

  **Variables:** lowercase identifiers (`x`, `my_var`)

  **Operators** (by precedence, lowest to highest):

  - `or`
  - `and`
  - `==`, `!=`, `<`, `>`, `<=`, `>=` (operands must share a type; strings use lexicographic order)
  - `+`, `-`
  - `*`, `/`, `%`
  - `not` (unary)
  - `-` (unary)

  **Functions:** `name(arg1, arg2)` — built-ins include `abs`, `between`, `ceil`,
  `clamp`, `coalesce`, `concat`, `contains`, `ends_with`, `floor`, `if`,
  `length`, `lower`, `match`, `max`, `min`, `mod`, `pi`, `pow`, `rem`, `round`,
  `sqrt`, `starts_with`, `trim`, and `upper`. `min`, `max`, and `coalesce` accept
  two or more arguments. See modules under `Elex.Functions.*`.

  **Short-circuit:** `and`, `or`, and `if(condition, a, b)` skip evaluating
  operands or branches that cannot affect the result.

  Parentheses group sub-expressions: `(1 + 2) * 3`

  ## Examples

      context = Elex.new_context() |> Elex.add_variable("x", 10)
      Elex.Parser.parse("x + 5", context)
      #=> {:ok, {:+, [{:var, "x"}, #Decimal<5>]}, :decimal}

  """
  import NimbleParsec

  alias Elex.Context
  alias Elex.Parser.ErrorFormatter
  alias Elex.Parser.StringEscape
  alias Elex.Validator

  # Maximum parenthesis/function-call nesting depth accepted by `parse/3`.
  # The grammar backtracks, so parse time grows exponentially with nesting
  # depth (a few dozen nested parentheses take seconds); this bound stops a
  # tiny but deeply nested input from exhausting CPU. Overridable per call via
  # the `:max_depth` option.
  @default_max_depth 16

  ws = repeat(ascii_char([?\s, ?\t])) |> label("whitespace")
  ws_req = times(ascii_char([?\s, ?\t]), min: 1) |> label("whitespace")

  literal_boolean =
    choice([
      string("false") |> replace(false),
      string("no") |> replace(false),
      string("true") |> replace(true),
      string("yes") |> replace(true)
    ])
    |> lookahead_not(ascii_char([?a..?z, ?0..?9, ?_]))
    |> label("boolean")

  literal_null =
    string("null")
    |> lookahead_not(ascii_char([?a..?z, ?0..?9, ?_]))
    |> replace(nil)
    |> label("null")

  literal_decimal =
    optional(string("-"))
    |> concat(ascii_string([?0..?9], min: 1))
    |> optional(concat(ascii_char([?.]), ascii_string([?0..?9], min: 1)))
    |> reduce(:to_decimal)
    |> label("number")

  defp to_decimal(acc) do
    {decimal, ""} = acc |> List.to_string() |> Decimal.parse()
    decimal
  end

  defp codepoint_to_string(codepoint) do
    <<codepoint::utf8>>
  end

  escaped_sequence =
    StringEscape.escapes()
    |> Enum.map(fn {char, replacement} ->
      string("\\" <> <<char::utf8>>) |> replace(replacement)
    end)
    |> then(&choice/1)

  unescaped_char =
    lookahead_not(choice([string("\""), string("\\")]))
    |> utf8_char([])
    |> map(:codepoint_to_string)

  literal_string =
    ignore(string("\""))
    |> repeat(
      choice([
        escaped_sequence,
        unescaped_char
      ])
    )
    |> reduce({Enum, :join, []})
    |> ignore(string("\""))
    |> label("string")

  identifier =
    ascii_char([?a..?z])
    |> repeat(ascii_char([?a..?z, ?0..?9, ?_]))
    |> reduce({List, :to_string, []})
    |> label("identifier")

  variable =
    identifier
    |> lookahead_not(ignore(ws) |> ascii_char([?(]))
    |> unwrap_and_tag(:var)

  defcombinatorp(:argument, parsec(:expr_or))

  argument_list =
    choice([
      parsec(:argument)
      |> repeat(
        ignore(ws)
        |> ignore(ascii_char([?,]))
        |> ignore(ws)
        |> concat(parsec(:argument))
      ),
      empty()
    ])
    |> label("argument list")

  function_call =
    identifier
    |> ignore(ws)
    |> ignore(ascii_char([?(]))
    |> ignore(ws)
    |> concat(argument_list)
    |> ignore(ws)
    |> ignore(ascii_char([?)]))
    |> reduce(:reduce_function_call)
    |> label("function")

  defp reduce_function_call([name | args_list]) when is_list(args_list) do
    {:func, name, length(args_list), args_list}
  end

  defp reduce_function_call([name]) do
    {:func, name, 0, []}
  end

  # Alternative ordering here is significant for error reporting, not just for
  # matching. When every branch fails, NimbleParsec surfaces the failure of the
  # *last* alternative it tried. Keeping `function_call` last means malformed
  # calls such as `max(1 2)` report the position deep inside the argument list
  # (the unexpected `2`) instead of collapsing back to the opening parenthesis.
  # `variable` must come before `function_call` (and carries a `lookahead_not`
  # for `(`) so an identifier followed by `(` is always parsed as a call.
  expr_value =
    choice([
      ignore(ascii_char([?(]))
      |> ignore(ws)
      |> concat(parsec(:expr_or))
      |> ignore(ws)
      |> ignore(ascii_char([?)])),
      literal_decimal,
      literal_boolean,
      literal_null,
      literal_string,
      variable,
      function_call
    ])
    |> label("expression")

  defcombinatorp(
    :expr_not,
    choice([
      string("not")
      |> lookahead_not(ascii_char([?a..?z, ?0..?9, ?_]))
      |> ignore(ws_req)
      |> concat(parsec(:expr_not))
      |> reduce(:unary_op),
      ascii_char([?-])
      |> ignore(ws)
      |> concat(parsec(:expr_not))
      |> reduce(:unary_negate_op),
      expr_value
    ])
  )

  defp reduce_left_assoc([term]), do: term

  defp reduce_left_assoc([term | rest]) do
    Enum.reduce(Enum.chunk_every(rest, 2), term, fn [op, term], acc ->
      case op do
        b when is_integer(b) ->
          {String.to_atom(<<op>>), [acc, term]}

        s ->
          {String.to_atom(s), [acc, term]}
      end
    end)
  end

  defcombinatorp(
    :expr_mul,
    parsec(:expr_not)
    |> repeat(
      ignore(ws)
      |> ascii_char([?*, ?/, ?%])
      |> ignore(ws)
      |> concat(parsec(:expr_not))
    )
    |> reduce(:reduce_left_assoc)
  )

  defcombinatorp(
    :expr_sum,
    parsec(:expr_mul)
    |> repeat(
      ignore(ws)
      |> ascii_char([?+, ?-])
      |> ignore(ws)
      |> concat(parsec(:expr_mul))
    )
    |> reduce(:reduce_left_assoc)
  )

  defcombinatorp(
    :expr_cmp,
    choice([
      parsec(:expr_sum)
      |> ignore(ws)
      |> choice([
        string("<="),
        string("<") |> lookahead_not(ascii_char([?=])),
        string(">="),
        string(">") |> lookahead_not(ascii_char([?=])),
        string("=="),
        string("!=")
      ])
      |> ignore(ws)
      |> concat(parsec(:expr_sum)),
      parsec(:expr_sum)
    ])
    |> reduce(:reduce_left_assoc)
  )

  defcombinatorp(
    :expr_and,
    parsec(:expr_cmp)
    |> repeat(
      ignore(ws_req)
      |> string("and")
      |> lookahead_not(ascii_char([?a..?z, ?0..?9, ?_]))
      |> ignore(ws_req)
      |> concat(parsec(:expr_cmp))
    )
    |> reduce(:reduce_left_assoc)
  )

  defcombinatorp(
    :expr_or,
    parsec(:expr_and)
    |> repeat(
      ignore(ws_req)
      |> string("or")
      |> lookahead_not(ascii_char([?a..?z, ?0..?9, ?_]))
      |> ignore(ws_req)
      |> concat(parsec(:expr_and))
    )
    |> reduce(:reduce_left_assoc)
  )

  defparsecp(:do_parse, ignore(ws) |> concat(parsec(:expr_or)) |> ignore(ws) |> concat(eos()))

  defp unary_op([op, a]), do: {String.to_atom(op), a}

  defp unary_negate_op([?-, a]), do: {:-, a}

  @typedoc """
  Low-level parse details returned by [`debug/1`](`debug/1`).

  - `:expression` - the original input string
  - `:status` - `:ok` when the whole input parsed, `:error` otherwise
  - `:ast` - the parsed AST on success, `nil` on error
  - `:reason` - the raw NimbleParsec error message on error, `nil` on success
  - `:consumed` - the leading portion of the input the parser accepted
  - `:rest` - the unconsumed remainder at the furthest position reached
  - `:line` / `:column` - 1-based line and 0-based column of that position.
    NimbleParsec does not track intra-line columns for this grammar, so
    `:column` is `0` for single-line expressions; use `:byte_offset` to locate
    the position instead.
  - `:byte_offset` - byte offset of that position into the input
  """
  @type debug_info :: %{
          expression: String.t(),
          status: :ok | :error,
          ast: term() | nil,
          reason: String.t() | nil,
          consumed: String.t(),
          rest: String.t(),
          line: pos_integer(),
          column: non_neg_integer(),
          byte_offset: non_neg_integer()
        }

  @doc """
  Parses an expression and returns the raw, low-level parser state.

  This is a development and debugging aid: it exposes exactly what the
  underlying NimbleParsec parser produced (including the raw error message,
  how far it got, and what input was left over) without validating the AST
  against a context or translating errors into human-readable messages.

  Use [`parse/3`](`parse/3`) for normal parsing.

  ## Options

  - `:max_depth` - Maximum parenthesis/function-call nesting depth. Expressions
    nested more deeply are rejected before parsing (mirroring [`parse/3`](`parse/3`)),
    guarding against resource exhaustion from pathologically nested input. The
    returned map has `status: :error` with the same reason [`parse/3`](`parse/3`)
    reports. Must be a non-negative integer; an invalid value yields an error map
    rather than silently disabling the guard. Defaults to `#{@default_max_depth}`.

  ## Returns

  A [`debug_info`](`t:debug_info/0`) map. See its documentation for the fields.

  ## Examples

      iex> info = Elex.Parser.debug("( 1 + 2")
      iex> info.status
      :error
      iex> info.rest
      "( 1 + 2"

      iex> info = Elex.Parser.debug("1 + 2")
      iex> info.status
      :ok
      iex> info.rest
      ""

  """
  @spec debug(String.t(), keyword()) :: debug_info()
  def debug(expression, opts \\ []) when is_binary(expression) do
    max_depth = Keyword.get(opts, :max_depth, @default_max_depth)

    cond do
      not valid_max_depth?(max_depth) ->
        build_debug_info(expression, :error, nil, invalid_max_depth_reason(), expression, 1, 0, 0)

      deeper_than?(expression, max_depth) ->
        build_debug_info(expression, :error, nil, too_deep_reason(max_depth), expression, 1, 0, 0)

      true ->
        debug_parse(expression)
    end
  end

  defp debug_parse(expression) do
    case do_parse(expression) do
      {:ok, [ast], rest, _ctx, {line, column}, byte_offset} ->
        build_debug_info(expression, :ok, ast, nil, rest, line, column, byte_offset)

      {:error, reason, rest, _ctx, {line, column}, byte_offset} ->
        build_debug_info(expression, :error, nil, reason, rest, line, column, byte_offset)
    end
  end

  defp build_debug_info(expression, status, ast, reason, rest, line, column, byte_offset) do
    %{
      expression: expression,
      status: status,
      ast: ast,
      reason: reason,
      consumed: binary_part(expression, 0, byte_offset),
      rest: rest,
      line: line,
      column: column,
      byte_offset: byte_offset
    }
  end

  @doc """
  Parses an expression string and optionally validates the resulting AST against a context.

  ## Parameters

  - `expression` - The expression string to parse
  - `context` - A [`Elex.Context`](Elex.Context) with variables and functions
  - `opts` - Keyword list of options (see below)

  ## Options

  - `:validate` - Whether to validate the AST against the context. Defaults to `true`.
    When `false`, the returned type is `nil`.
  - `:max_depth` - Maximum parenthesis/function-call nesting depth. Expressions
    nested more deeply are rejected with an error before parsing, guarding
    against resource exhaustion from pathologically nested input. Defaults to
    `#{@default_max_depth}`.

  ## Returns

  - `{:ok, ast, type}` - Parsed (and optionally validated) AST with result type
  - `{:error, reason}` - Parse or validation error message

  ## Examples

      context = Elex.new_context() |> Elex.add_variable("x", 10)
      Elex.Parser.parse("x + 5", context)
      #=> {:ok, {:+, [{:var, "x"}, #Decimal<5>]}, :decimal}

      Elex.Parser.parse("unknown_var", context)
      #=> {:error, "variable 'unknown_var' does not exist"}

  """
  @spec parse(String.t(), Context.t(), keyword()) :: {:ok, term(), atom()} | {:error, String.t()}
  def parse(expression, context, opts \\ []) do
    validate? = Keyword.get(opts, :validate, true)
    max_depth = Keyword.get(opts, :max_depth, @default_max_depth)

    cond do
      not valid_max_depth?(max_depth) ->
        {:error, invalid_max_depth_reason()}

      deeper_than?(expression, max_depth) ->
        {:error, too_deep_reason(max_depth)}

      true ->
        parse_and_validate(expression, context, validate?)
    end
  end

  # `max_depth` must be a non-negative integer; anything else (a negative
  # integer, a string, `nil`, ...) is rejected rather than silently disabling
  # the nesting guard.
  defp valid_max_depth?(value), do: is_integer(value) and value >= 0

  defp invalid_max_depth_reason, do: "invalid max_depth: must be a non-negative integer"

  defp too_deep_reason(max_depth),
    do: "expression is nested too deeply (maximum depth is #{max_depth})"

  defp parse_and_validate(expression, context, validate?) do
    case do_parse(expression) do
      {:ok, [ast], "", _, _, _} ->
        validate_or_return_ast(ast, context, validate?)

      {:ok, [_ast], rest, _, _, byte_offset} ->
        {:error, humanize_error(expression, rest, byte_offset)}

      {:error, _reason, rest, _, _, byte_offset} ->
        {:error, humanize_error(expression, rest, byte_offset)}
    end
  end

  defp validate_or_return_ast(ast, context, true) do
    case Validator.validate(ast, context) do
      {:ok, type} -> {:ok, ast, type}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_or_return_ast(ast, _context, false), do: {:ok, ast, nil}

  # Cheap O(n) scan of the maximum parenthesis nesting depth, returning `true`
  # as soon as `limit` is exceeded so it never walks the whole input needlessly.
  # Parentheses inside string literals are ignored (matching the grammar's
  # string handling); delimiters are ASCII, so scanning by byte is safe for
  # UTF-8 input.
  defp deeper_than?(expression, limit), do: deeper_than?(expression, limit, 0, false)

  defp deeper_than?(<<>>, _limit, _depth, _in_string), do: false

  # Inside a string literal every escape is a backslash followed by one character.
  defp deeper_than?(<<?\\, _rest::binary>> = bin, limit, depth, true) do
    case StringEscape.skip_binary(bin) do
      nil -> deeper_than?(<<>>, limit, depth, true)
      rest -> deeper_than?(rest, limit, depth, true)
    end
  end

  defp deeper_than?(<<?", rest::binary>>, limit, depth, in_string),
    do: deeper_than?(rest, limit, depth, not in_string)

  defp deeper_than?(<<_char, rest::binary>>, limit, depth, true),
    do: deeper_than?(rest, limit, depth, true)

  defp deeper_than?(<<?(, _rest::binary>>, limit, depth, false) when depth + 1 > limit, do: true

  defp deeper_than?(<<?(, rest::binary>>, limit, depth, false),
    do: deeper_than?(rest, limit, depth + 1, false)

  defp deeper_than?(<<?), rest::binary>>, limit, depth, false),
    do: deeper_than?(rest, limit, max(depth - 1, 0), false)

  defp deeper_than?(<<_char, rest::binary>>, limit, depth, false),
    do: deeper_than?(rest, limit, depth, false)

  # NimbleParsec discards how far it got inside a failed `choice`/`repeat`, so a
  # malformed sub-expression nested inside a group or argument list surfaces at
  # the enclosing `(` or `,` rather than at the real problem. Before formatting,
  # descend into that group or argument and re-parse it so the message points at
  # the deepest, most specific failure.
  defp humanize_error(expression, rest, byte_offset) do
    {expr, rest, offset} = locate_deepest(expression, rest, byte_offset)
    ErrorFormatter.humanize(expr, rest, offset)
  end

  defp locate_deepest(expression, rest, byte_offset) do
    case descend(expression, rest, byte_offset) do
      nil -> {expression, rest, byte_offset}
      {sub, sub_rest, sub_offset} -> locate_deepest(sub, sub_rest, sub_offset)
    end
  end

  defp descend(expression, rest, byte_offset) do
    remainder = String.trim_leading(rest)
    consumed = binary_part(expression, 0, byte_offset)

    cond do
      # The parser stalled right before a parenthesised group it could not
      # consume where a value was expected: re-parse the group's interior. We
      # skip this when a value was just completed (e.g. `1 (...)`), so that a
      # stray group is reported as an unexpected `(` rather than descended into.
      String.starts_with?(remainder, "(") and expects_value?(consumed) ->
        descend_group(remainder)

      # The parser stalled at a comma inside an argument list: re-parse the
      # argument that follows it (bounded by the enclosing closing parenthesis).
      String.starts_with?(remainder, ",") ->
        descend_arguments(remainder)

      true ->
        nil
    end
  end

  defp descend_group(remainder) do
    case split_group(remainder) do
      {inner, _after} -> if blank?(inner), do: nil, else: reparse_failure(inner)
      nil -> nil
    end
  end

  defp descend_arguments("," <> rest) do
    rest
    |> arguments_until_close()
    |> split_top_level_commas()
    |> first_failing_argument()
  end

  # A value is expected (so a following group is worth descending into) at the
  # start of the input or immediately after an operator, keyword, comma, or
  # opening parenthesis - but not after a completed value.
  defp expects_value?(consumed) do
    trimmed = String.trim_trailing(consumed)

    trimmed == "" or String.last(trimmed) in ~w[+ - * / % < > = ! ( ,] or
      Regex.match?(~r/(?:^|[^a-z0-9_])(?:and|or|not)$/, trimmed)
  end

  defp blank?(string), do: String.trim(string) == ""

  defp first_failing_argument([]), do: nil

  defp first_failing_argument([segment | rest]) do
    case String.trim(segment) do
      # An empty argument (a double or trailing comma) is best described by the
      # existing "unexpected ','" message, so stop descending here.
      "" -> nil
      trimmed -> reparse_failure(trimmed) || first_failing_argument(rest)
    end
  end

  # Returns `{sub_expression, rest, offset}` when `sub` does not parse cleanly,
  # or `nil` when it parses fully (so there is nothing deeper to report).
  defp reparse_failure(sub) do
    case do_parse(sub) do
      {:ok, [_ast], "", _, _, _} -> nil
      {:ok, [_ast], rest, _, _, offset} -> {sub, rest, offset}
      {:error, _reason, rest, _, _, offset} -> {sub, rest, offset}
    end
  end

  # Given a binary starting with `(`, returns `{interior, rest_after_close}`
  # where `interior` is the content between the outer parentheses. Returns `nil`
  # when there is no matching close. Parentheses inside string literals are
  # ignored. Delimiters are ASCII, so scanning by byte is safe for UTF-8 input.
  defp split_group("(" <> rest), do: split_group(rest, 0, false, "")

  defp split_group(<<>>, _depth, _in_string, _acc), do: nil

  defp split_group(<<?\\, _rest::binary>> = bin, depth, true, acc) do
    case StringEscape.skip_binary(bin) do
      nil -> split_group(<<>>, depth, true, <<acc::binary, ?\\>>)
      rest -> split_group(rest, depth, true, acc)
    end
  end

  defp split_group(<<?", rest::binary>>, depth, in_string, acc),
    do: split_group(rest, depth, not in_string, <<acc::binary, ?">>)

  defp split_group(<<char, rest::binary>>, depth, true, acc),
    do: split_group(rest, depth, true, <<acc::binary, char>>)

  defp split_group(<<?(, rest::binary>>, depth, false, acc),
    do: split_group(rest, depth + 1, false, <<acc::binary, ?(>>)

  defp split_group(<<?), rest::binary>>, 0, false, acc), do: {acc, rest}

  defp split_group(<<?), rest::binary>>, depth, false, acc),
    do: split_group(rest, depth - 1, false, <<acc::binary, ?)>>)

  defp split_group(<<char, rest::binary>>, depth, false, acc),
    do: split_group(rest, depth, false, <<acc::binary, char>>)

  # Collects the argument-list text that follows a comma, stopping at the
  # closing parenthesis of the enclosing call (the first `)` at outer depth).
  defp arguments_until_close(binary), do: arguments_until_close(binary, 0, false, "")

  defp arguments_until_close(<<>>, _depth, _in_string, acc), do: acc

  defp arguments_until_close(<<?\\, _rest::binary>> = bin, depth, true, acc) do
    case StringEscape.skip_binary(bin) do
      nil -> arguments_until_close(<<>>, depth, true, <<acc::binary, ?\\>>)
      rest -> arguments_until_close(rest, depth, true, acc)
    end
  end

  defp arguments_until_close(<<?", rest::binary>>, depth, in_string, acc),
    do: arguments_until_close(rest, depth, not in_string, <<acc::binary, ?">>)

  defp arguments_until_close(<<char, rest::binary>>, depth, true, acc),
    do: arguments_until_close(rest, depth, true, <<acc::binary, char>>)

  defp arguments_until_close(<<?(, rest::binary>>, depth, false, acc),
    do: arguments_until_close(rest, depth + 1, false, <<acc::binary, ?(>>)

  defp arguments_until_close(<<?), _rest::binary>>, 0, false, acc), do: acc

  defp arguments_until_close(<<?), rest::binary>>, depth, false, acc),
    do: arguments_until_close(rest, depth - 1, false, <<acc::binary, ?)>>)

  defp arguments_until_close(<<char, rest::binary>>, depth, false, acc),
    do: arguments_until_close(rest, depth, false, <<acc::binary, char>>)

  # Splits an argument list on commas that sit at the outer level, ignoring
  # commas nested in parentheses or string literals.
  defp split_top_level_commas(binary), do: split_top_level_commas(binary, 0, false, "", [])

  defp split_top_level_commas(<<>>, _depth, _in_string, current, acc),
    do: Enum.reverse([current | acc])

  defp split_top_level_commas(<<?\\, _rest::binary>> = bin, depth, true, current, acc) do
    case StringEscape.skip_binary(bin) do
      nil ->
        split_top_level_commas(<<>>, depth, true, <<current::binary, ?\\>>, acc)

      rest ->
        split_top_level_commas(rest, depth, true, current, acc)
    end
  end

  defp split_top_level_commas(<<?", rest::binary>>, depth, in_string, current, acc),
    do: split_top_level_commas(rest, depth, not in_string, <<current::binary, ?">>, acc)

  defp split_top_level_commas(<<char, rest::binary>>, depth, true, current, acc),
    do: split_top_level_commas(rest, depth, true, <<current::binary, char>>, acc)

  defp split_top_level_commas(<<?,, rest::binary>>, 0, false, current, acc),
    do: split_top_level_commas(rest, 0, false, "", [current | acc])

  defp split_top_level_commas(<<?(, rest::binary>>, depth, false, current, acc),
    do: split_top_level_commas(rest, depth + 1, false, <<current::binary, ?(>>, acc)

  defp split_top_level_commas(<<?), rest::binary>>, depth, false, current, acc),
    do: split_top_level_commas(rest, max(depth - 1, 0), false, <<current::binary, ?)>>, acc)

  defp split_top_level_commas(<<char, rest::binary>>, depth, false, current, acc),
    do: split_top_level_commas(rest, depth, false, <<current::binary, char>>, acc)
end
