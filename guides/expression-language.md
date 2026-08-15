# Expression Language

Elex expressions are strings that combine literals, variables, operators, and
function calls. This page describes the language syntax and semantics.

## Literals

### Numbers

Decimal numbers use standard notation. Unary minus is supported:

```elixir
Elex.evaluate("42", context)      # #Decimal<42>
Elex.evaluate("3.14", context)    # #Decimal<3.14>
Elex.evaluate("-5.5", context)    # #Decimal<-5.5>
Elex.evaluate("-(1 + 2)", context) # #Decimal<-3>
```

All arithmetic is performed with `Decimal` for precision.

### Booleans

```elixir
Elex.evaluate("true", context)
Elex.evaluate("false", context)
Elex.evaluate("yes", context)   # alias for true
Elex.evaluate("no", context)    # alias for false
```

### Strings

Strings are double-quoted. Backslash introduces an escape sequence:

| Sequence | Meaning |
|----------|---------|
| `\"` | double quote |
| `\\` | backslash |
| `\n` | newline |
| `\t` | tab |
| `\r` | carriage return |
| `\f` | form feed |
| `\b` | backspace |

Any other `\` sequence is a parse error. Use `\\` when you need a literal
backslash, for example in regex patterns:

```elixir
Elex.evaluate(~s["hello"], context)
Elex.evaluate(~s["say \"hi\""], context)
Elex.evaluate(~s["line1\\nline2"], context)
Elex.evaluate(~s[match("abc123", "\\\\d+")], context)
```

### Null

The `null` literal represents an empty or missing value:

```elixir
Elex.evaluate("null", context)  # nil
```

`null` compares equal only to `null` or `nil` variables. It cannot be compared
to numbers, booleans, or strings with `<`, `>`, etc.

## Variables

Variable names start with a lowercase letter and may contain letters, digits, and
underscores (`price`, `tax_rate`, `item2`).

The words `and`, `or`, `not`, `null`, `true`, `false`, `yes`, and `no` are
reserved and cannot be used as variable names.

Variables must be present in the evaluation context (with a known type) before
an expression can be validated or evaluated.

## Operators

### Precedence (lowest to highest)

| Level | Operators |
|-------|-----------|
| 1 | `or` |
| 2 | `and` |
| 3 | `==`, `!=`, `<`, `>`, `<=`, `>=` |
| 4 | `+`, `-` (binary) |
| 5 | `*`, `/`, `%` |
| 6 | `not` (unary) |
| 7 | `-` (unary minus) |

Parentheses override precedence: `(1 + 2) * 3`.

### Arithmetic

`+`, `-`, `*`, `/`, and `%` require decimal operands and return a decimal.

The `%` operator is remainder (sign follows the dividend), same as `rem(a, b)`.
For floored modulo, use the `mod(a, b)` function instead.

### Comparisons

Comparison operators return a boolean. Operands must have the same type:

- **Decimals** — numeric ordering
- **Strings** — lexicographic ordering
- **Booleans** — `true`/`false` ordering
- **Null** — equality (`==`, `!=`) only

```elixir
{:ok, true}  = Elex.evaluate("10 > 5", context)
{:ok, true}  = Elex.evaluate(~s["a" < "b"], context)
{:ok, true}  = Elex.evaluate("null == null", context)
```

### Logical operators

`and`, `or`, and `not` require boolean operands and return a boolean.

`and`, `or`, and `if(condition, a, b)` use **short-circuit evaluation**: the
right-hand operand (or unselected branch) is skipped when it cannot change the
result. This prevents errors in guard-style expressions:

```elixir
{:ok, false} = Elex.evaluate("false and (1 / 0 > 0)", context)
{:ok, true}  = Elex.evaluate("true or (1 / 0 > 0)", context)
{:ok, result} = Elex.evaluate("if(false, 1 / 0, 2)", context)  # #Decimal<2>
```

## Type system

Elex performs static type checking during parsing (by default). Each sub-expression
has a type; operators and functions enforce compatibility before evaluation.

| Type | Description | Example values |
|------|-------------|----------------|
| `:decimal` | Numbers | `#Decimal<3.14>` |
| `:boolean` | True/false | `true`, `false` |
| `:string` | Text | `"hello"` |
| `nil` | Null | `null`, nil variables |

Type errors are reported as human-readable strings, for example:

```
'+' operator can not be used on number and text
```

## Function calls

Functions use familiar call syntax: `name(arg1, arg2)`. See the
[Functions](functions.md) reference for the full list.

`min`, `max`, and `coalesce` are variadic — they accept two or more arguments.
`concat` is also variadic and accepts one or more string arguments.

`pi()` takes no arguments.

## Limits

- **Nesting depth** — By default, parenthesis/function-call nesting deeper than
  16 levels is rejected. Override with the `:max_depth` option on
  `Elex.Parser.parse/3`.
- **Reserved words** — `and`, `or`, `not`, `null`, `true`, `false`, `yes`, and
  `no` cannot be variable names.

## Further reading

- [Functions](functions.md) — built-in function reference
- [Advanced Topics](advanced.md) — working with the AST directly
