# Ash Integration

Elex ships an optional Ash resource validation that type-checks expression
strings stored on Ash attributes. The validation runs when the attribute
changes on a changeset.

## Setup

Add both Elex and Ash to your dependencies:

```elixir
def deps do
  [
    {:elex, "~> 0.2.0"},
    {:ash, "~> 3.22"}
  ]
end
```

`Elex.AshValidation` is compiled only when Ash is available. Without Ash in
your dependency tree, the module is not present.

## Basic usage

Validate that a `:formula` attribute contains an expression returning a decimal:

```elixir
defmodule MyApp.Product do
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

When a user submits an invalid expression, Ash returns a changeset error with a
human-readable message from Elex.

## Options

| Option | Required | Description |
|--------|----------|-------------|
| `:attribute` | yes | Atom name of the string attribute holding the expression |
| `:context` | yes | `Elex.Context` with allowed variables and functions |
| `:expected_type` | yes | `:decimal`, `:boolean`, or `:string` |
| `:add_value_type_from_attribute` | no | Attribute atom; adds a `"value"` variable typed from that attribute's current value |
| `:description` | no | Custom text included in validation error messages |

## Context with variables

Pass a context that includes every variable your users may reference:

```elixir
context =
  Elex.new_context()
  |> Elex.add_variables(%{
    "price" => 0,
    "quantity" => 0
  })

validations do
  validate Elex.AshValidation,
    attribute: :formula,
    context: context,
    expected_type: :decimal
end
```

Variables in the context need types for validation to succeed, but their values
are not used during validation — only types matter.

## Validating against the current value

Use `:add_value_type_from_attribute` when expressions may reference a `value`
variable representing the attribute being validated:

```elixir
attributes do
  attribute :threshold, :decimal
  attribute :condition, :string
end

validations do
  validate Elex.AshValidation,
    attribute: :condition,
    context: Elex.new_context(),
    expected_type: :boolean,
    add_value_type_from_attribute: :threshold
end
```

This lets users write expressions like `value > 100` where `value` is typed as
`:decimal` from the `:threshold` attribute.

## What gets validated

On change, `Elex.AshValidation`:

1. Reads the new value of the target attribute (skips validation when unchanged)
2. Parses the expression string with `Elex.Parser.parse/3`
3. Checks the result type matches `:expected_type`
4. Returns `:ok` or an `Ash.Error.Changes.InvalidAttribute` error

Parse and type errors surface as attribute errors with the expression string as
the invalid value.

## Further reading

- `Elex.AshValidation` — full API reference
- [Getting Started](getting-started.md) — building contexts and validating expressions
- [Expression Language](expression-language.md) — syntax reference
