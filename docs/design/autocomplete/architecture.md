# Autocomplete architecture

Internals for [expression autocomplete](index.md). Behaviour is canonical in [user-flows.md](user-flows.md).

## Components

| Module | Role |
|---|---|
| `Elex.autocomplete/4` | Public wrapper: validate opts, delegate |
| `Elex.Autocomplete` | Scan → slot → candidates → prefix filter → sort |
| `Elex.CharClass` | Shared ident / unit / digit / whitespace byte classes used by both `Elex.Parser` and `Elex.Autocomplete`. Internal (`@moduledoc false`); not a public Hex module. Number, string, and operator lexing stay in the autocomplete scanner (intentionally not extracted here) |
| `Elex.Context` | Variables and `list_functions/1` (unchanged) |
| `Elex.Units.Catalog` | Walk `categories[].units` and `aliases` (no new catalog API required) |
| `Elex.Function.units/1` | Detect `:convert` / `:wrap` for the unit-string slot |

Do not reuse `Elex.Parser.parse/3` for the incomplete prefix. NimbleParsec is all-or-nothing; the motivating input `1 + (2 * f` is already a parse error.

## Data flow

1. Reject unknown opts; require `empty_prefix` in `[:none, :all]` (default `:none`). Raise `ArgumentError` otherwise.
2. If `cursor` is not an integer, or not a UTF-8 boundary, or not in `0..byte_size(expression)`, return `{:error, "cursor is out of range"}`.
3. Tokenize the expression enough to find the token that contains the cursor (look **ahead** of the cursor for the token end, and **back** for the token start).
4. `range = {start, end}` exclusive end. `prefix = binary_part(expression, start, cursor - start)`.
5. Classify the **slot** from tokens before `start` (and string/function-call nesting).
6. If slot is `:none`, return `{:ok, %{range: range, suggestions: []}}`.
7. If `prefix == ""` and `empty_prefix: :none`, return `{:ok, %{range: range, suggestions: []}}`.
8. Collect candidates for the slot from the context / catalog; keep `String.starts_with?(text, prefix)`; sort by `:text`; return `{:ok, %{range, suggestions}}`.

## Token under the cursor

**Replacement range** (`replacement_range/2`): walk back and forward from `cursor` over one continue class — bytes `a-z`, `A-Z`, `0-9`, `_`, and `^` (bare `^` continues even when no digit follows). After skipping a complete number prefix in that span, keep the range only when the first remaining byte is a letter (`a-z` or `A-Z`); otherwise the range is empty (`{cursor, cursor}`).

**Slot tokenization** (`take_ident/1`): the same letter-led ident covers identifiers and unit atoms — start on a letter, then letters, digits, `_`, and `^` plus following digits. There is no separate lowercase-only class for identifiers versus a wider class for unit atoms.

| Token | Notes |
|---|---|
| Identifier / keyword / function name / unit atom | One letter-led walk as above. Variables and function names are lowercase in the language; unit atoms may use `A-Z` and optional `^`+digits |
| Number | parser number (`digits`, optional `.digits`, optional `e/E` exponent **with a digit**). Unit suffix attaches only when this token is **complete** |
| String | from `"` to closing `"` or EOF; escapes as in the expression language |
| Operator / punct | `+ - * / % < > = ! ( ) ,` including two-char `<= >= == !=` |

Whitespace is not part of the replacement range. Cursor in whitespace → empty token, `range: {cursor, cursor}`.

## Slots

Classify using the last **complete** token(s) before `start` and whether the current token is glued to a number.

### `:operand`

A value is expected:

- start of input
- after `(` or `,`
- after a binary operator
- after unary `not` or unary `-`

**Candidates:** context variables; unique function names; keywords `true`, `false`, `yes`, `no`, `null`, `not`.

**Not:** units, `and`, `or`.

### `:unit_suffix_glued`

Cursor is in (or immediately after) a complete number with **no** whitespace between the number and the current token (`10|`, `10m|`).

**Candidates:** catalog canonical names and aliases (empty list if `context.units` is `nil`).

**Not:** variables, functions, `and` / `or` (`10and` is not infix).

### `:after_number_space`

Complete number, then whitespace, then the current token (`10 |`, `10 m|`, `10 a|`).

**Candidates:** units (if catalog) **plus** `and`, `or`.

**Not:** variables, functions (`10 max` is juxtaposition).

### `:infix`

A complete non-number value (identifier, keyword literal, `)`, finished call) then whitespace, then the current token (`true a|`, `foo |`).

**Candidates:** `and`, `or`.

**Not:** units, variables, functions.

### `:unit_string`

Cursor is inside a string literal that is the **second argument** of a call whose function module has `Elex.Function.units(module)` in `[:convert, :wrap]`. Unclosed `"` still counts.

**Candidates:** catalog canonical names and aliases.

**Not:** variables, functions, keywords.

### `:none`

Anything else: other strings, incomplete operators (`=|`), incomplete numbers (`10.|`, `10e+|`), comments (N/A — the language has none).

**Candidates:** none. `empty_prefix: :all` does not apply.

## Candidate sources

- **Variables:** `Map.keys(context.variables)` as `%{kind: :variable, text: name}`.
- **Functions:** `Context.list_functions/1`, one row per `name`, first remaining after that list’s order, as `%{kind: :function, text, signature, description}` and `:category` when present.
- **Keywords:** fixed lists above as `%{kind: :keyword, text: name}`.
- **Units:** every canonical unit name and every alias in `context.units`. `%{kind: :unit, text: spelling}`. Skip when `units` is `nil`.

## Error handling

| Input | Result |
|---|---|
| Cursor outside `0..byte_size`, negative, or mid-codepoint | `{:error, "cursor is out of range"}` |
| No matching prefix, empty prefix with default, or slot `:none` | `{:ok, %{range, suggestions: []}}` |
| Unknown option key | `ArgumentError` `"unknown option :…"` |
| `empty_prefix` not `:none` or `:all` | `ArgumentError` naming `empty_prefix` |

Autocomplete never returns parser/validate error strings for a broken expression. Incomplete input is the normal case.
