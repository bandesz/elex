defmodule Elex.Parser do
  import NimbleParsec

  alias Elex.Context
  alias Elex.Validator

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

  escaped_quote = string("\\\"") |> replace("\"")

  unescaped_char =
    lookahead_not(choice([string("\""), string("\\")]))
    |> utf8_char([])
    |> map(:codepoint_to_string)

  literal_string =
    ignore(string("\""))
    |> repeat(
      choice([
        escaped_quote,
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

  def reduce_function_call([name | args_list]) when is_list(args_list) do
    {:func, name, length(args_list), args_list}
  end

  def reduce_function_call([name]) do
    {:func, name, 0, []}
  end

  expr_value =
    choice([
      ignore(ascii_char([?(]))
      |> ignore(ws)
      |> concat(parsec(:expr_or))
      |> ignore(ws)
      |> ignore(ascii_char([?)])),
      literal_decimal,
      literal_boolean,
      literal_string,
      function_call,
      variable
    ])
    |> label("expression")

  expr_not =
    choice([
      string("not")
      |> lookahead_not(ascii_char([?a..?z, ?0..?9, ?_]))
      |> ignore(ws_req)
      |> concat(expr_value)
      |> reduce(:unary_op),
      expr_value
    ])

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
    expr_not
    |> repeat(
      ignore(ws)
      |> ascii_char([?*, ?/])
      |> ignore(ws)
      |> concat(expr_not)
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

  @doc """
  Parses an expression string and optionally validates the resulting AST against a context.


    * `:validate` - Whether to validate the AST. Defaults to `true`.


    * `{:ok, ast, type}` - If parsing (and optionally validation) is successful.
    * `{:error, reason}` - If parsing or validation fails.
  """
  @spec parse(String.t(), Context.t(), keyword()) :: {:ok, term(), atom()} | {:error, String.t()}
  def parse(expression, context, opts \\ []) do
    validate? = Keyword.get(opts, :validate, true)

    case do_parse(expression) do
      {:ok, [ast], "", _, _, _} ->
        validate_or_return_ast(ast, context, validate?)

      {:error, reason, _rest, _, {line, _col}, _byte_offset} ->
        {:error, "Parse error at line #{line}: #{reason}"}
    end
  end

  defp validate_or_return_ast(ast, context, true) do
    case Validator.validate(ast, context) do
      {:ok, type} -> {:ok, ast, type}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_or_return_ast(ast, _context, false), do: {:ok, ast, nil}
end
