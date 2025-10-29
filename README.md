# Elex

[![CI](https://github.com/bandesz/elex/actions/workflows/ci.yml/badge.svg)](https://github.com/bandesz/elex/actions/workflows/ci.yml)

Elex is a powerful expression language library for Elixir that provides parsing, validation, and evaluation of mathematical and logical expressions.

## Features

- **Arithmetic Operations**: `+`, `-`, `*`, `/`
- **Comparison Operators**: `<`, `>`, `<=`, `>=`, `==`, `!=`
- **Logical Operations**: `and`, `or`, `not`
- **Variables**: Dynamic variable substitution
- **Functions**: Built-in functions (`max`, `min`, `ceil`, `floor`, `round`, `sqrt`, `rem`, `if`, `pi`)
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

### Arithmetic

```elixir
context = Elex.new_context()

Elex.evaluate("10 + 5", context)   # => 15
Elex.evaluate("10 - 5", context)   # => 5
Elex.evaluate("10 * 5", context)   # => 50
Elex.evaluate("10 / 5", context)   # => 2
Elex.evaluate("2 + 3 * 4", context) # => 14 (respects precedence)
```

### Comparisons

```elixir
Elex.evaluate("10 > 5", Elex.new_context())   # => true
Elex.evaluate("10 < 5", Elex.new_context())   # => false
Elex.evaluate("10 >= 10", Elex.new_context()) # => true
Elex.evaluate("10 <= 5", Elex.new_context())  # => false
Elex.evaluate("10 == 10", Elex.new_context()) # => true
Elex.evaluate("10 != 5", Elex.new_context())  # => true
```

### Logical Operations

```elixir
Elex.evaluate("true and false", Elex.new_context()) # => false
Elex.evaluate("true or false", Elex.new_context())  # => true
Elex.evaluate("not true", Elex.new_context())       # => false
```

### Functions

```elixir
context = Elex.new_context()

Elex.evaluate("max(10, 20)", context)      # => 20
Elex.evaluate("min(10, 20)", context)      # => 10
Elex.evaluate("ceil(3.2)", context)        # => 4
Elex.evaluate("floor(3.8)", context)       # => 3
Elex.evaluate("round(3.5)", context)       # => 4
Elex.evaluate("sqrt(16)", context)         # => 4
Elex.evaluate("rem(10, 3)", context)       # => 1
Elex.evaluate("pi()", context)             # => 3.141592653589793
Elex.evaluate("if(10 > 5, 1, 0)", context) # => 1
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

    attribute :expected_type, :atom do
      constraints [one_of: [:decimal, :boolean, :string]]
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

## Expression Inversion

Elex can invert simple arithmetic expressions to solve for a variable:

```elixir
alias Elex.{Parser, Inverter}

context = Elex.new_context()
{:ok, ast, _type} = Parser.parse("value * 2 + 5", context, validate: false)
inverted_ast = Inverter.invert(ast, "value")

# The inverted expression solves for "value":
# value = (result - 5) / 2
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

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

