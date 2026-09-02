# Units validate / evaluate

**Date:** 2026-08-24  
**Status:** implemented  
**Living design:** [docs/design/units/](../design/units/index.md)

## Problem

Validate returns a **category formula** (base categories → exponents). Unregistered products are valid (`1hour * 1hour` is `time^2`). Evaluate stores a **unit monomial** on `%Elex.Unit{}`. Callers who need “this field is a speed” pass `category:` to `Elex.validate` (Ash uses the same check). Unit formulas use `|`, which does not collide with expression division.

## User journeys

See [docs/design/units/user-flows.md](../design/units/user-flows.md). Summary:

1. Units off — `1cm` in validate / evaluate / extract_variables is `unexpected 'cm'`.
2. Validate without `category:` — `1m * 1m` succeeds; returns category formula `length^2` even with no `:area`.
3. Validate with `category: :speed` — `1cm / 1s` succeeds and still returns `length | time`; `1m * 1m` errors that speed was expected.
4. Evaluate — always a **unit monomial** (`1cm / 1s` → `cm | s`). Optional `unit: "km | h"` converts. Dim mismatch uses the **target**’s category: `expression should return a valid length result`.
5. Helper — `cm | s` is compatible with `:speed` even if `cm/s` is not registered.

## Architecture

### Two monomials

| Layer | Keys | Example (`1cm / (1g * 1s * 1s)`) |
|---|---|---|
| Validate | Base **categories** (atoms) | `%{length: 1, mass: -1, time: -2}` → inspect `length \| mass * time^2` |
| Evaluate | **Unit symbols** (strings) | `%{"cm" => 1, "g" => -1, "s" => -2}` → inspect `cm \| g * s^2` |

Never collapse to a derived name (`:force`, `:speed`). `category: :speed` looks up speed’s formula (`length | time`) and requires a match; success still returns the inferred formula.

`%Elex.Unit{}` is **only** a unit monomial. Inspect always formats the monomial with `|`.

Category formulas are a parallel struct (`%Elex.Dimension{monomial: %{length: 1, time: -1}}`) returned by `validate` when the result is unitful. Primitives stay `:decimal` / `:boolean` / `:string`.

### Formula language (strings only)

Not the expression language. Used for catalog `default:` / unit names, derived `formula:`, `unit:`, `convert/2`, and inspect.

- Factor: `symbol` or `symbol^integer` (negative exponents OK: `s^-1`)
- Multiply: `*`, middot (`·` U+00B7 or `⋅` U+22C5), or whitespace (`kg m` = `kg * m`; `ms` is the symbol `ms`)
- At most one `|`. Left = numerator, right = denominator. `/` and parentheses are invalid
- Empty denominator rejected; inverse is `s^-1` or `1 | s` (not `| s`)
- Derived category: `formula: "length | time^2"`
- Inspect computed monomials: `#Elex.Quantity<10 m | s^2>`, `#Elex.Quantity<1 kg * m | s^2>`

Expression arithmetic still uses `/`: `"10m / 1s"`.

### APIs

```elixir
Elex.validate(expr, ctx)
Elex.validate(expr, ctx, category: :speed)

Elex.evaluate(expr, ctx)
Elex.evaluate(expr, ctx, unit: "km | h")

Elex.Unit.compatible?(unit, :speed, catalog)
```

- `category:` / `unit:` with no catalog, or unknown `category:` → **raise**
- Ash `expected_type: :length` passes `category: :length` into validate

Internals still thread dim vectors for operators (`min(1m, 1km)` same category, not same monomial). Root need not be a registered category.

### Helper

Map each symbol in a unit monomial to its category, combine exponents, compare to the category’s formula (or to another category formula). `cm | s` vs `:speed` is true.

## Error handling

**Validate, no `category:`:** operator/type errors only (`cannot add length and mass`). Unregistered products are OK.

**Validate, `category: :speed`:** formula is not `length | time` → speed was expected (including boolean/decimal results).

**Evaluate, `unit:` dim mismatch:** look up the **target** unit’s category → `expression should return a valid length result`. Unknown symbol: `unknown unit 'm2'`. Missing identity for a conversion (area monomial → `ha`) is a `put_units` failure.

**`convert/2`:** keep `cannot convert length to mass`.

**Units off:** `unexpected 'cm'` (no new “units disabled” message).

## Testing

ExUnit / TDD; fixtures in `test/support/elex/units/`.

- `1m * 1m` → dimension `length^2`; `category: :length` errors
- `1cm / 1s` + `category: :speed` → `length | time`
- Evaluate `1mm` → `%{"mm" => 1}`; `1m * 1m` → `%{"m" => 2}`
- `unit: "km | h"` converts; `unit: "mm"` on speed → valid length result
- Formula: accept `|` / juxtaposition; reject `/` and two `|`
- `Unit.compatible?` for `cm | s` vs `:speed`
- Units off unchanged
