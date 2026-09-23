defmodule Elex.Autocomplete do
  @moduledoc """
  Completes identifiers in an Elex expression without requiring a successful parse.

  [`Elex.autocomplete/4`](`Elex.autocomplete/4`) delegates here after validating options.
  The scanner classifies the token under the cursor and the syntactic slot, then
  prefix-filters candidates from the context.
  """

  alias Elex.CharClass
  alias Elex.Context
  alias Elex.Function
  alias Elex.Units.Catalog

  @after_operand_ops ~w{( , + - * / % < > <= >= == !=}
  @after_operand_idents ~w(not and or)
  @operand_keywords ~w(true false yes no null not)
  @infix_keywords ~w(and or)

  @spec complete(String.t(), term(), Context.t(), :none | :all) ::
          {:ok, %{range: {non_neg_integer(), non_neg_integer()}, suggestions: [map()]}}
          | {:error, String.t()}
  def complete(expression, cursor, context, empty_prefix) do
    case validate_cursor(expression, cursor) do
      :ok ->
        {range_start, range_end} = replacement_range(expression, cursor)
        prefix = binary_part(expression, range_start, cursor - range_start)
        slot = classify_slot(expression, range_start, context)
        suggestions = suggestions_for(slot, prefix, empty_prefix, context)
        {:ok, %{range: {range_start, range_end}, suggestions: suggestions}}

      {:error, _reason} = error ->
        error
    end
  end

  defp validate_cursor(_expression, cursor) when not is_integer(cursor) do
    {:error, "cursor is out of range"}
  end

  defp validate_cursor(expression, cursor) do
    size = byte_size(expression)

    if cursor >= 0 and cursor <= size and utf8_boundary?(expression, cursor) do
      :ok
    else
      {:error, "cursor is out of range"}
    end
  end

  defp utf8_boundary?(_binary, 0), do: true
  defp utf8_boundary?(binary, offset) when offset == byte_size(binary), do: true

  defp utf8_boundary?(binary, offset) do
    <<_prefix::binary-size(^offset), byte, _rest::binary>> = binary
    Bitwise.band(byte, 0xC0) != 0x80
  end

  defp replacement_range(expression, cursor) do
    raw_start = ident_start(expression, cursor)
    range_end = ident_end(expression, cursor)
    range_start = skip_complete_number(expression, raw_start, range_end)

    if range_start < range_end and unit_symbol_at?(expression, range_start) do
      {range_start, range_end}
    else
      {cursor, cursor}
    end
  end

  defp ident_start(_expression, 0), do: 0

  defp ident_start(expression, offset) do
    prev = offset - 1

    cond do
      ident_continue?(:binary.at(expression, prev)) ->
        ident_start(expression, prev)

      degree_before?(expression, offset) ->
        offset - byte_size("°")

      true ->
        offset
    end
  end

  defp degree_before?(expression, offset) do
    size = byte_size("°")
    offset >= size and binary_part(expression, offset - size, size) == "°"
  end

  defp unit_symbol_at?(expression, offset) do
    case expression do
      <<_::binary-size(^offset), c::utf8, _::binary>> -> CharClass.unit_symbol_start?(c)
      <<_::binary-size(^offset), c::utf8>> -> CharClass.unit_symbol_start?(c)
      _ -> false
    end
  end

  defp ident_end(expression, offset) do
    size = byte_size(expression)
    ident_end(expression, offset, size)
  end

  defp ident_end(_expression, offset, size) when offset >= size, do: size

  defp ident_end(expression, offset, size) do
    cond do
      degree_at?(expression, offset) ->
        ident_end_continue(expression, offset + byte_size("°"), size)

      ident_continue?(:binary.at(expression, offset)) ->
        ident_end(expression, offset + 1, size)

      true ->
        offset
    end
  end

  defp ident_end_continue(_expression, offset, size) when offset >= size, do: size

  defp ident_end_continue(expression, offset, size) do
    if ident_continue?(:binary.at(expression, offset)) do
      ident_end_continue(expression, offset + 1, size)
    else
      offset
    end
  end

  defp degree_at?(expression, offset) do
    size = byte_size("°")
    offset + size <= byte_size(expression) and binary_part(expression, offset, size) == "°"
  end

  defp skip_complete_number(expression, start, range_end) when start < range_end do
    slice = binary_part(expression, start, range_end - start)
    start + complete_number_size(slice)
  end

  defp skip_complete_number(_expression, start, _range_end), do: start

  defp complete_number_size(<<c, _::binary>> = binary) do
    if CharClass.digit?(c) do
      {_digits, rest} = take_digits(binary)
      rest = drop_complete_exponent(rest)
      byte_size(binary) - byte_size(rest)
    else
      0
    end
  end

  defp drop_complete_exponent(<<e, rest::binary>> = original) when e in [?e, ?E] do
    case rest do
      <<d, _::binary>> = digits ->
        if CharClass.digit?(d) do
          {_exp, rest_after} = take_digits(digits)
          rest_after
        else
          original
        end

      _ ->
        original
    end
  end

  defp drop_complete_exponent(rest), do: rest

  defp ident_continue?(byte) do
    CharClass.unit_continue?(byte) or byte == ?^
  end

  defp classify_slot(expression, range_start, context) do
    tokens = tokenize(binary_part(expression, 0, range_start))
    spaced? = range_start > 0 and whitespace?(:binary.at(expression, range_start - 1))
    classify_tokens(tokens, spaced?, context)
  end

  defp classify_tokens(tokens, spaced?, context) do
    if unit_string_slot?(tokens, context) do
      :unit_string
    else
      classify_after_prefix(List.last(tokens), spaced?)
    end
  end

  defp classify_after_prefix({:string, :unclosed}, _spaced?), do: :none
  defp classify_after_prefix(nil, _spaced?), do: :operand
  defp classify_after_prefix({:number, _}, true), do: :after_number_space
  defp classify_after_prefix({:number, _}, _spaced?), do: :unit_suffix_glued
  defp classify_after_prefix({:incomplete_number, _}, _spaced?), do: :none

  defp classify_after_prefix(last, spaced?) do
    cond do
      token_expects_operand?(last) -> :operand
      spaced? -> :infix
      true -> :none
    end
  end

  defp unit_string_slot?(tokens, context) do
    case {List.last(tokens), current_call(tokens)} do
      {{:string, :unclosed}, {name, 1}} -> convert_or_wrap?(name, context)
      _ -> false
    end
  end

  defp current_call(tokens) do
    {stack, _pending} =
      Enum.reduce(tokens, {[], nil}, fn
        {:ident, name}, {stack, _} ->
          {stack, name}

        {:op, "("}, {stack, name} when is_binary(name) ->
          {[{name, 0} | stack], nil}

        {:op, "("}, {stack, _} ->
          {[{nil, 0} | stack], nil}

        {:op, ")"}, {[_ | rest], _} ->
          {rest, nil}

        {:op, ")"}, {[], _} ->
          {[], nil}

        {:op, ","}, {[{name, idx} | rest], _} ->
          {[{name, idx + 1} | rest], nil}

        {:op, ","}, {[], _} ->
          {[], nil}

        _token, {stack, _} ->
          {stack, nil}
      end)

    case stack do
      [{name, idx} | _] when is_binary(name) -> {name, idx}
      _ -> nil
    end
  end

  defp convert_or_wrap?(name, context) do
    context
    |> Context.list_functions()
    |> Enum.any?(fn
      %{name: ^name, module: module} -> Function.units(module) in [:convert, :wrap]
      _ -> false
    end)
  end

  defp token_expects_operand?({:op, op}), do: op in @after_operand_ops
  defp token_expects_operand?({:ident, name}), do: name in @after_operand_idents
  defp token_expects_operand?(_token), do: false

  defp suggestions_for(_slot, "", :none, _context), do: []

  defp suggestions_for(slot, prefix, _empty_prefix, context) do
    slot
    |> candidates(prefix, context)
    |> Enum.sort_by(& &1.text)
  end

  defp candidates(:operand, prefix, context) do
    variable_suggestions(context, prefix) ++
      function_suggestions(context, prefix) ++
      keyword_suggestions(@operand_keywords, prefix)
  end

  defp candidates(:infix, prefix, _context) do
    keyword_suggestions(@infix_keywords, prefix)
  end

  defp candidates(:after_number_space, prefix, context) do
    unit_suggestions(context, prefix) ++ keyword_suggestions(@infix_keywords, prefix)
  end

  defp candidates(slot, prefix, context) when slot in [:unit_suffix_glued, :unit_string] do
    unit_suggestions(context, prefix)
  end

  defp candidates(_slot, _prefix, _context), do: []

  defp unit_suggestions(%Context{units: nil}, _prefix), do: []

  defp unit_suggestions(%Context{units: %Catalog{categories: categories}}, prefix) do
    categories
    |> Map.values()
    |> Enum.flat_map(fn %{units: units} ->
      Enum.flat_map(units, fn {name, unit} ->
        [name | Map.get(unit, :aliases, [])]
      end)
    end)
    |> Enum.filter(&String.starts_with?(&1, prefix))
    |> Enum.map(&%{kind: :unit, text: &1})
  end

  defp variable_suggestions(%Context{variables: variables}, prefix) do
    variables
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, prefix))
    |> Enum.map(&%{kind: :variable, text: &1})
  end

  defp function_suggestions(context, prefix) do
    context
    |> Context.list_functions()
    |> Enum.uniq_by(& &1.name)
    |> Enum.filter(&String.starts_with?(&1.name, prefix))
    |> Enum.map(&function_suggestion/1)
  end

  defp function_suggestion(info) do
    info
    |> Map.take([:signature, :description, :category])
    |> Map.put(:kind, :function)
    |> Map.put(:text, info.name)
  end

  defp keyword_suggestions(keywords, prefix) do
    keywords
    |> Enum.filter(&String.starts_with?(&1, prefix))
    |> Enum.map(&%{kind: :keyword, text: &1})
  end

  defp tokenize(expression), do: do_tokenize(expression, [])

  defp do_tokenize(<<>>, acc), do: Enum.reverse(acc)

  defp do_tokenize(<<c::utf8, rest::binary>> = binary, acc) do
    cond do
      CharClass.whitespace?(c) ->
        do_tokenize(rest, acc)

      CharClass.unit_symbol_start?(c) ->
        {ident, rest_after} = take_ident(binary)
        do_tokenize(rest_after, [{:ident, ident} | acc])

      CharClass.digit?(c) ->
        {kind, number, rest_after} = take_number(binary)
        do_tokenize(rest_after, [{kind, number} | acc])

      true ->
        do_tokenize_other(binary, acc)
    end
  end

  defp do_tokenize(<<_::8, rest::binary>>, acc), do: do_tokenize(rest, acc)

  defp do_tokenize_other(<<?", rest::binary>>, acc) do
    {_string, rest_after, status} = take_string(rest)
    do_tokenize(rest_after, [{:string, status} | acc])
  end

  defp do_tokenize_other(<<a, b, rest::binary>>, acc)
       when (a == ?< and b == ?=) or (a == ?> and b == ?=) or (a == ?= and b == ?=) or
              (a == ?! and b == ?=) do
    do_tokenize(rest, [{:op, <<a, b>>} | acc])
  end

  defp do_tokenize_other(<<c, rest::binary>>, acc)
       when c in [?+, ?-, ?*, ?/, ?%, ?<, ?>, ?=, ?!, ?(, ?), ?,] do
    do_tokenize(rest, [{:op, <<c>>} | acc])
  end

  defp do_tokenize_other(<<_::8, rest::binary>>, acc) do
    do_tokenize(rest, acc)
  end

  defp take_ident(<<c::utf8, rest::binary>> = binary) do
    if CharClass.unit_symbol_start?(c) do
      take_ident_continue(rest, <<c::utf8>>)
    else
      {<<>>, binary}
    end
  end

  defp take_ident(binary), do: {<<>>, binary}

  defp take_ident_continue(<<c::utf8, rest::binary>> = binary, acc) do
    if CharClass.unit_continue?(c) do
      take_ident_continue(rest, acc <> <<c::utf8>>)
    else
      take_ident_power_or_stop(binary, acc)
    end
  end

  defp take_ident_continue(rest, acc), do: take_ident_power_or_stop(rest, acc)

  defp take_ident_power_or_stop(<<?^, d, rest::binary>> = binary, acc) do
    if CharClass.digit?(d) do
      {digits, rest_after} = take_digits(<<d, rest::binary>>)
      {acc <> <<?^>> <> digits, rest_after}
    else
      {acc, binary}
    end
  end

  defp take_ident_power_or_stop(rest, acc), do: {acc, rest}

  defp take_number(binary) do
    {digits, rest} = take_digits(binary)

    case rest do
      <<?., d, more::binary>> ->
        if CharClass.digit?(d) do
          {frac, rest_after} = take_digits(<<d, more::binary>>)
          take_exponent(rest_after, digits <> <<?.>> <> frac)
        else
          {:incomplete_number, digits <> <<?.>>, <<d, more::binary>>}
        end

      <<?., rest_after::binary>> ->
        {:incomplete_number, digits <> <<?.>>, rest_after}

      _ ->
        take_exponent(rest, digits)
    end
  end

  defp take_exponent(<<e, rest::binary>>, acc) when e in [?e, ?E] do
    {acc, rest} =
      case rest do
        <<sign, more::binary>> when sign in [?+, ?-] -> {acc <> <<e, sign>>, more}
        _ -> {acc <> <<e>>, rest}
      end

    case rest do
      <<d, _::binary>> = rest ->
        if CharClass.digit?(d) do
          {exp, rest_after} = take_digits(rest)
          {:number, acc <> exp, rest_after}
        else
          {:incomplete_number, acc, rest}
        end

      rest ->
        {:incomplete_number, acc, rest}
    end
  end

  defp take_exponent(rest, acc), do: {:number, acc, rest}

  defp take_digits(binary), do: take_digits(binary, <<>>)

  defp take_digits(<<c, rest::binary>> = binary, acc) do
    if CharClass.digit?(c) do
      take_digits(rest, acc <> <<c>>)
    else
      {acc, binary}
    end
  end

  defp take_digits(rest, acc), do: {acc, rest}

  defp take_string(binary), do: take_string(binary, <<>>)

  defp take_string(<<>>, acc), do: {acc, <<>>, :unclosed}
  defp take_string(<<?", rest::binary>>, acc), do: {acc <> <<?">>, rest, :closed}

  defp take_string(<<?\\, c, rest::binary>>, acc) do
    take_string(rest, acc <> <<?\\, c>>)
  end

  defp take_string(<<c, rest::binary>>, acc) do
    take_string(rest, acc <> <<c>>)
  end

  defp whitespace?(byte), do: CharClass.whitespace?(byte)
end
