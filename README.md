# Elex

[![CI](https://github.com/bandesz/elex/actions/workflows/ci.yml/badge.svg)](https://github.com/bandesz/elex/actions/workflows/ci.yml)

Elex is a powerful expression language library for Elixir that provides parsing, validation, and evaluation of mathematical and logical expressions.

## Features

- **Arithmetic Operations**: `+`, `-`, `*`, `/`
- **Comparison Operators**: `<`, `>`, `<=`, `>=`, `==`, `!=`
- **Logical Operations**: `and`, `or`, `not`
- **Variables**: Dynamic variable substitution
- **Functions**: Built-in functions (`max`, `min`, `ceil`, `floor`, `round`, `sqrt`, `rem`, `if`, `pi`) and custom functions via `Elex.Function`
- **Type System**: Static type checking and validation
- **Decimal Precision**: Uses `Decimal` for accurate arithmetic
- **Expression Inversion**: Solve for variables in simple expressions
- **Ash Integration**: Optional Ash validation for resource attributes

## Installation

Add `elex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elex, "~> 0.1.0"}
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
```

### Variables

Variable names must start with a lowercase letter and may contain letters, digits, and underscores. The words `and`, `or`, and `not` are reserved and cannot be used as variable names.

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
{:ok, result} = Elex.evaluate("2 + 3 * 4", context) # => #Decimal<14> (respects precedence)
```

> **Note:** `Elex.evaluate/2` returns `{:ok, result}` on success or `{:error, reason}` on failure. Arithmetic operations use `Decimal` and return `Decimal` values.

### Comparisons

```elixir
{:ok, true} = Elex.evaluate("10 > 5", Elex.new_context())
{:ok, false} = Elex.evaluate("10 < 5", Elex.new_context())
{:ok, true} = Elex.evaluate("10 >= 10", Elex.new_context())
{:ok, false} = Elex.evaluate("10 <= 5", Elex.new_context())
{:ok, true} = Elex.evaluate("10 == 10", Elex.new_context())
{:ok, true} = Elex.evaluate("10 != 5", Elex.new_context())
```

### Logical Operations

```elixir
{:ok, false} = Elex.evaluate("true and false", Elex.new_context())
{:ok, true} = Elex.evaluate("true or false", Elex.new_context())
{:ok, false} = Elex.evaluate("not true", Elex.new_context())
```

### Functions

```elixir
context = Elex.new_context()

{:ok, result} = Elex.evaluate("max(10, 20)", context)      # => #Decimal<20>
{:ok, result} = Elex.evaluate("min(10, 20)", context)      # => #Decimal<10>
{:ok, result} = Elex.evaluate("ceil(3.2)", context)        # => #Decimal<4>
{:ok, result} = Elex.evaluate("floor(3.8)", context)       # => #Decimal<3>
{:ok, result} = Elex.evaluate("round(3.5)", context)       # => #Decimal<4>
{:ok, result} = Elex.evaluate("sqrt(16)", context)         # => #Decimal<4>
{:ok, result} = Elex.evaluate("rem(10, 3)", context)       # => #Decimal<1>
{:ok, result} = Elex.evaluate("pi()", context)             # => #Decimal<3.141592653589793238462643383279502884197169399375105820974>
{:ok, result} = Elex.evaluate("if(10 > 5, 1, 0)", context) # => #Decimal<1>
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

