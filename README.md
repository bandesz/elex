# Elex

[![CI](https://github.com/bandesz/elex/actions/workflows/ci.yml/badge.svg)](https://github.com/bandesz/elex/actions/workflows/ci.yml)

Elex is a powerful expression language library for Elixir that provides parsing, validation, and evaluation of mathematical and logical expressions.

## Documentation

Full guides are available on [hexdocs.pm](https://hexdocs.pm/elex):

- [Getting Started](https://hexdocs.pm/elex/getting-started.html)
- [Expression Language](https://hexdocs.pm/elex/expression-language.html)
- [Functions](https://hexdocs.pm/elex/functions.html)
- [Ash Integration](https://hexdocs.pm/elex/ash-integration.html)
- [Advanced Topics](https://hexdocs.pm/elex/advanced.html)

## Features

- **Arithmetic Operations**: `+`, `-`, `*`, `/`, `%` (modulo), unary `-`
- **Comparison Operators**: `<`, `>`, `<=`, `>=`, `==`, `!=` (numbers and strings)
- **Logical Operations**: `and`, `or`, `not` (with short-circuit evaluation)
- **Literals**: Decimal numbers, booleans (`true`/`false`, `yes`/`no`), strings, and `null`
- **Variables**: Dynamic variable substitution
- **Functions**: Built-in math, string, and utility functions (see [Functions](#functions)) and custom functions via `Elex.Function`
- **Type System**: Static type checking and validation
- **Decimal Precision**: Uses `Decimal` for accurate arithmetic
- **Expression Inversion**: Solve for variables in simple expressions
- **Ash Integration**: Optional Ash validation for resource attributes

## Installation

Add `elex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elex, "~> 0.2.0"}
  ]
end
```

## Quick Start

```elixir
# Create a context with variables
context = Elex.new_context()
  |> Elex.add_variable("price", 100)
  |> Elex.add_variable("tax_rate", 0.08)

# Evaluate an expression
{:ok, result} = Elex.evaluate("price * (1 + tax_rate)", context)
# result => Decimal.new("108")

# Validate expression type
{:ok, :decimal} = Elex.validate("price + 10", context)
{:ok, :boolean} = Elex.validate("price > 50", context)

# Extract variables from an expression
{:ok, ["price", "quantity"]} = Elex.extract_variables("price * quantity")
```

## Expression Syntax

### Literals

```elixir
# Numbers (decimal)
Elex.evaluate("42", Elex.new_context())
Elex.evaluate("3.14", Elex.new_context())
Elex.evaluate("-5.5", Elex.new_context())

# Booleans
Elex.evaluate("true", Elex.new_context())
Elex.evaluate("false", Elex.new_context())
Elex.evaluate("yes", Elex.new_context())  # alias for true
Elex.evaluate("no", Elex.new_context())   # alias for false

# Strings
Elex.evaluate("\"hello\"", Elex.new_context())

# Null
Elex.evaluate("null", Elex.new_context())
```

`null` compares equal only to `null` or `nil` variables (`null == null`, `x == null` when `x` is nil). It cannot be compared to numbers, booleans, or strings.

### Variables

Variable names must start with a lowercase letter and may contain letters, digits, and underscores. The words `and`, `or`, `not`, `null`, `true`, `false`, `yes`, and `no` are reserved and cannot be used as variable names.

```elixir
context =
  Elex.new_context()
  |> Elex.add_variable("price", 100)
  |> Elex.add_variable("tax_rate", 0.08)

{:ok, result} = Elex.evaluate("price * (1 + tax_rate)", context)
# result => #Decimal<108>
```

### Arithmetic

```elixir
context = Elex.new_context()

{:ok, result} = Elex.evaluate("10 + 5", context)   # => #Decimal<15>
{:ok, result} = Elex.evaluate("10 - 5", context)   # => #Decimal<5>
{:ok, result} = Elex.evaluate("10 * 5", context)   # => #Decimal<50>
{:ok, result} = Elex.evaluate("10 / 5", context)   # => #Decimal<2>
{:ok, result} = Elex.evaluate("10 % 3", context)   # => #Decimal<1>
{:ok, result} = Elex.evaluate("2 + 3 * 4", context) # => #Decimal<14> (respects precedence)
{:ok, result} = Elex.evaluate("-5", context)       # => #Decimal<-5> (unary minus)
{:ok, result} = Elex.evaluate("-(1 + 2)", context) # => #Decimal<-3>
```

> **Note:** `Elex.evaluate/2` returns `{:ok, result}` on success or `{:error, reason}` on failure. Arithmetic operations use `Decimal` and return `Decimal` values. The `%` operator has the same precedence as `*` and `/`.

### Comparisons

```elixir
{:ok, true} = Elex.evaluate("10 > 5", Elex.new_context())
{:ok, false} = Elex.evaluate("10 < 5", Elex.new_context())
{:ok, true} = Elex.evaluate("10 >= 10", Elex.new_context())
{:ok, false} = Elex.evaluate("10 <= 5", Elex.new_context())
{:ok, true} = Elex.evaluate("10 == 10", Elex.new_context())
{:ok, true} = Elex.evaluate("10 != 5", Elex.new_context())

# String ordering (lexicographic)
{:ok, true} = Elex.evaluate(~s["a" < "b"], Elex.new_context())
{:ok, true} = Elex.evaluate(~s["b" >= "a"], Elex.new_context())
```

Comparison operands must have the same type (decimal, boolean, string, or null).

### Logical Operations

```elixir
{:ok, false} = Elex.evaluate("true and false", Elex.new_context())
{:ok, true} = Elex.evaluate("true or false", Elex.new_context())
{:ok, false} = Elex.evaluate("not true", Elex.new_context())
```

`and`, `or`, and `if(condition, a, b)` use short-circuit evaluation: the right-hand operand (or unselected branch) is not evaluated when its result cannot change the outcome. This avoids errors such as division by zero in guard expressions:

```elixir
{:ok, false} = Elex.evaluate("false and (1 / 0 > 0)", Elex.new_context())
{:ok, true} = Elex.evaluate("true or (1 / 0 > 0)", Elex.new_context())
{:ok, result} = Elex.evaluate("if(false, 1 / 0, 2)", Elex.new_context()) # => #Decimal<2>
```

### Functions

#### Math

| Function | Description |
|----------|-------------|
| `abs(x)` | Absolute value |
| `ceil(x)`, `floor(x)`, `round(x)` | Rounding |
| `sqrt(x)` | Square root |
| `pow(base, exp)` | Exponentiation |
| `rem(a, b)` | Remainder (sign follows the dividend; same as `%`) |
| `mod(a, b)` | Floored modulo (sign follows the divisor) |
| `max(a, b, …)`, `min(a, b, …)` | Largest or smallest of two or more numbers (variadic) |
| `clamp(x, min, max)` | Clamp `x` to an inclusive range |
| `between(x, low, high)` | `true` when `x` is in the inclusive range |
| `pi()` | Mathematical constant π |
| `if(cond, a, b)` | Conditional (short-circuits; branches must share a type) |

```elixir
context = Elex.new_context()

{:ok, result} = Elex.evaluate("max(10, 20)", context)           # => #Decimal<20>
{:ok, result} = Elex.evaluate("max(3, 7, 9)", context)         # => #Decimal<9>
{:ok, result} = Elex.evaluate("min(10, 20)", context)          # => #Decimal<10>
{:ok, result} = Elex.evaluate("abs(-5)", context)              # => #Decimal<5>
{:ok, result} = Elex.evaluate("pow(2, 3)", context)             # => #Decimal<8>
{:ok, result} = Elex.evaluate("mod(10, 3)", context)            # => #Decimal<1>
{:ok, result} = Elex.evaluate("clamp(15, 0, 10)", context)     # => #Decimal<10>
{:ok, result} = Elex.evaluate("between(5, 0, 10)", context)   # => true
{:ok, result} = Elex.evaluate("ceil(3.2)", context)            # => #Decimal<4>
{:ok, result} = Elex.evaluate("floor(3.8)", context)           # => #Decimal<3>
{:ok, result} = Elex.evaluate("round(3.5)", context)           # => #Decimal<4>
{:ok, result} = Elex.evaluate("sqrt(16)", context)              # => #Decimal<4>
{:ok, result} = Elex.evaluate("rem(10, 3)", context)           # => #Decimal<1>
{:ok, result} = Elex.evaluate("pi()", context)                  # => #Decimal<3.14159…>
{:ok, result} = Elex.evaluate("if(10 > 5, 1, 0)", context)    # => #Decimal<1>
```

#### Strings

| Function | Description |
|----------|-------------|
| `concat(a, b)` | Concatenate two strings |
| `length(s)` | String length (character count) |
| `contains(haystack, needle)` | Substring search |
| `match(text, pattern)` | Regex match |
| `starts_with(s, prefix)`, `ends_with(s, suffix)` | Prefix/suffix test |
| `lower(s)`, `upper(s)`, `trim(s)` | Case and whitespace transforms |
| `coalesce(a, b, …)` | First non-null argument (variadic; short-circuits) |

```elixir
context = Elex.new_context()

{:ok, result} = Elex.evaluate(~s[concat("hello", " world")], context)     # => "hello world"
{:ok, result} = Elex.evaluate(~s[length("abc")], context)                  # => #Decimal<3>
{:ok, result} = Elex.evaluate(~s[contains("hello", "ell")], context)       # => true
{:ok, result} = Elex.evaluate(~s[match("hello123", "hello[0-9]+")], context)  # => true
{:ok, result} = Elex.evaluate(~s[starts_with("hello", "he")], context)     # => true
{:ok, result} = Elex.evaluate(~s[ends_with("hello", "lo")], context)        # => true
{:ok, result} = Elex.evaluate(~s[lower("ABC")], context)                      # => "abc"
{:ok, result} = Elex.evaluate(~s[upper("abc")], context)                   # => "ABC"
{:ok, result} = Elex.evaluate(~s[trim("  x  ")], context)                   # => "x"
{:ok, result} = Elex.evaluate("coalesce(null, 5)", context)                  # => #Decimal<5>
```

## Ash Integration

Elex provides an optional Ash validation for validating expressions in resource attributes:

```elixir
defmodule MyApp.Resource do
  use Ash.Resource

  attributes do
    attribute :formula, :string do
      allow_nil? false
    end
  end

  validations do
    validate Elex.AshValidation,
      attribute: :formula,
      context: Elex.new_context(),
      expected_type: :decimal
  end
end
```

The `expected_type` option accepts `:decimal`, `:boolean`, or `:string`. Use `add_value_type_from_attribute` to inject a `value` variable typed from another attribute — useful when validating formulas that reference the current value.

## Expression Inversion

Elex can invert simple arithmetic expressions to solve for a variable:

```elixir
alias Elex.{Parser, Inverter}

context = Elex.new_context()
{:ok, ast, _type} = Parser.parse("value * 2 + 5", context, validate: false)
{:ok, inverted_ast} = Inverter.invert(ast, "value")

# The inverted expression solves for "value":
# value = (result - 5) / 2
```

## Custom Functions

Implement the `Elex.Function` behaviour and register your module with `Elex.Context.add_function/2`:

```elixir
defmodule MyApp.Functions.Double do
  @behaviour Elex.Function

  @impl true
  def signature, do: %{name: :double, arity: 1}

  @impl true
  def validate([arg], ctx), do: Elex.Validator.validate(arg, ctx)

  @impl true
  def call([arg]), do: {:ok, Decimal.mult(arg, Decimal.new(2))}

  @impl true
  def documentation, do: %{signature: "double(x)", description: "doubles a number"}
end

context =
  Elex.new_context()
  |> Elex.Context.add_function(MyApp.Functions.Double)

{:ok, result} = Elex.evaluate("double(5)", context)
```

## Development

### Setup

```bash
mix deps.get
mix test
```

### Git Hooks

To enable the pre-commit hook that runs quality checks before each commit:

```bash
git config core.hooksPath .git-hooks
```

The pre-commit hook runs:
- Code compilation with warnings as errors
- Code formatting
- Credo linting
- Sobelow security checks
- Dependency audit
- All tests

You can also run these checks manually:

```bash
mix precommit
```

### Code Quality

```bash
mix check          # Run all quality checks
mix format         # Format code
mix credo --strict # Run Credo linter
mix dialyzer       # Run Dialyzer type checker
mix sobelow        # Run security analysis
```

## License

Copyright (c) 2025 bandesz

See [LICENSE](LICENSE) for details.

