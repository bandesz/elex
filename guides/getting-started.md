# Getting Started

This guide walks through the most common way to use Elex: parse, validate, and
evaluate expression strings with variables.

## Installation

Add `elex` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:elex, "~> 0.2.0"}
  ]
end
```

If you plan to use Ash resource validation, also add Ash (Elex treats it as an
optional dependency):

```elixir
{:ash, "~> 3.22"}
```

## Your first expression

Create a context, add variables, and evaluate a formula:

```elixir
context =
  Elex.new_context()
  |> Elex.add_variable("price", 100)
  |> Elex.add_variable("tax_rate", 0.08)

{:ok, result} = Elex.evaluate("price * (1 + tax_rate)", context)
# result => #Decimal<108>
```

`Elex.evaluate/2` always returns `{:ok, result}` on success or `{:error, reason}`
on failure. Arithmetic uses the `Decimal` library, so numeric results are
`Decimal` structs rather than floats.

## Building a context

`Elex.new_context/0` creates a context with all built-in functions already
registered. Add variables one at a time or in bulk:

```elixir
context =
  Elex.new_context()
  |> Elex.add_variable("quantity", 3)
  |> Elex.add_variables(%{"price" => 10, "discount" => 0.1})
```

`Elex.add_variable/3` infers the variable type from the Elixir value:

| Elixir value | Inferred type |
|--------------|---------------|
| integer, float, `Decimal` | `:decimal` |
| string | `:string` |
| boolean | `:boolean` |
| `nil` | `nil` |
| anything else | `:unknown` |

For precise control, build a `%Elex.Variable{}` struct and use
`Elex.Context.add_variable/3` instead.

## Validating without evaluating

Use `Elex.validate/2` when you need to check syntax and types but not compute a
result — for example, validating user input in a form:

```elixir
context = Elex.new_context() |> Elex.add_variable("price", 100)

{:ok, :decimal} = Elex.validate("price + 10", context)
{:ok, :boolean} = Elex.validate("price > 50", context)
{:error, reason} = Elex.validate("price + \"oops\"", context)
```

The returned type is one of `:decimal`, `:boolean`, `:string`, or `nil` (for
expressions whose result is `null`).

## Discovering variables

Extract variable names from an expression without requiring them to exist in a
context:

```elixir
{:ok, ["price", "quantity"]} = Elex.extract_variables("price * quantity")
```

This is useful for building UIs that prompt users to supply values for every
referenced name.

## Handling errors

Parse, validation, and evaluation errors all come back as `{:error, reason}`
strings from `Elex.evaluate/2` and `Elex.validate/2`:

```elixir
# Parse error
{:error, "closing parenthesis is missing"} = Elex.evaluate("(1 + 2", context)

# Validation error
{:error, "variable 'missing' does not exist"} = Elex.evaluate("missing + 1", context)

# Evaluation error (e.g. division by zero)
{:error, "Evaluation error: ..."} = Elex.evaluate("1 / 0", context)
```

Error messages are written for humans writing expressions, not for debugging
the parser grammar.

## What to read next

- [Expression Language](expression-language.md) — operators, types, precedence, and
  short-circuit behaviour
- [Functions](functions.md) — built-in math and string functions
- [Ash Integration](ash-integration.md) — validating expressions on Ash resources
- [Advanced Topics](advanced.md) — AST format, expression inversion, and custom
  functions

For the full API reference, see the `Elex` module documentation.
