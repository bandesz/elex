# Getting Started

This guide walks through the most common way to use Elex: parse, validate, and
evaluate expression strings with variables.

## Installation

Add `elex` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:elex, "~> 0.2.3"}
  ]
end
```

Unit support is **Unreleased**; Hex `0.2.3` does not include it.

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
  |> Elex.add_variable!("price", 100)
  |> Elex.add_variable!("tax_rate", 0.08)

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
  |> Elex.add_variable!("quantity", 3)
  |> Elex.add_variables!(%{"price" => 10, "discount" => 0.1})
```

`Elex.add_variable/3` infers the variable type from the Elixir value and
returns `{:ok, context}`. Use `add_variable!/3` (and `add_variables!/2`)
when piping:

| Elixir value | Inferred type |
|--------------|---------------|
| integer, float, `Decimal` | `:decimal` |
| string | `:string` |
| boolean | `:boolean` |
| `nil` | `nil` |
| `{number, "unit"}` or `%Elex.Quantity{}` | that category (requires a catalog and `category:`) |
| anything else | `:unknown` |

With a units catalog, pass `category:` for a quantity value (see
[Optional units](#optional-units)):

```elixir
{:ok, context} = Elex.add_variable(context, "width", {10, "mm"}, category: :length)
```

For precise control, build a `%Elex.Variable{}` struct and use
`Elex.Context.add_variable/3` instead.

## Validating without evaluating

Use `Elex.validate/2` when you need to check syntax and types but not compute a
result — for example, validating user input in a form:

```elixir
context = Elex.new_context() |> Elex.add_variable!("price", 100)

{:ok, :decimal} = Elex.validate("price + 10", context)
{:ok, :boolean} = Elex.validate("price > 50", context)
{:error, reason} = Elex.validate("price + \"oops\"", context)
```

The returned type is one of `:decimal`, `:boolean`, `:string`, `nil` (for
expressions whose result is `null`), or `%Elex.Dimension{}` when a units
catalog is attached (`length`, `length | time`). See [Units](units.md).

## Optional units

Attach a catalog when expressions should carry quantities. `evaluate` then
returns `%Elex.Quantity{}`; `validate` returns `%Elex.Dimension{}`:

```elixir
alias Elex.Units.Catalog

{:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
{:ok, catalog} = Catalog.add_unit(catalog, :length, "m")
{:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
{:ok, context} = Elex.Context.put_units(Elex.new_context(), catalog)

{:ok, qty} = Elex.evaluate("10mm + 1m", context)
# qty => #Elex.Quantity<1.01 m>

{:ok, qty} = Elex.evaluate("10mm", context, unit: "m")
# qty => #Elex.Quantity<0.01 m>
```

See [Units](units.md) for suffixes, derived categories, and `convert/2`.

## Discovering variables

Extract variable names from an expression without requiring them to exist.
Pass a context so unit suffixes parse when a catalog is attached:

```elixir
{:ok, ["price", "quantity"]} = Elex.extract_variables("price * quantity", context)
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
{:error, "division by zero"} = Elex.evaluate("1 / 0", context)
```

Error messages are written for humans writing expressions, not for debugging
the parser grammar.

## What to read next

- [Expression Language](expression-language.md) — operators, types, precedence, and
  short-circuit behaviour
- [Functions](functions.md) — built-in math and string functions
- [Units](units.md) — optional unit catalogs, quantities, and `convert/2`
- [Ash Integration](ash-integration.md) — validating expressions on Ash resources
- [Advanced Topics](advanced.md) — AST format, expression inversion, and custom
  functions

For the full API reference, see the `Elex` module documentation.
