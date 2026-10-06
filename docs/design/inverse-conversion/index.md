# Inverse conversion

A non-additive category may register a formula whose dimension is the exact inverse of the category, when that unit's conversion is a reciprocal (`k / value`). `unit:` and `convert/2` then convert between `L | 100 km` and `mile | gallon` through the category default.

Follow-on to [denominator scale](../denominator-scale/index.md). This file is the design. User flows below are canonical.

## Implementation status

**Status:** complete
**Review fixes:** `454662b`

## Problem and constraints

Litres per 100 km and miles per gallon are the same fuel-economy fact. They are inverse dimensions, so a direct `unit:` from `8 {L | 100 km}` to `mile | gallon` is `expression should return a valid economy result` when each formula lives on its own category. Registering `mile | gallon` on the consumption category is `formula 'mile | gallon' does not match the category dimension`.

Opaque names in one non-additive category already convert with `235.215 / value`. That path stays. Callers who also want `L | 100 km` as a real volume-per-length formula need the inverse formula on that same category.

**Constraints:**

- Opt-in catalogs. Elex still ships no unit system.
- The category is non-additive. Reciprocal conversions stay illegal on additive categories.
- The conversion string is the whole map to the category default. For default `L | km`, `mile | gallon` is `k / value` with `k = 3.785411784 / 1.609344`, not `1 / value`.
- `per` on `L | 100 km` is applied once. The reciprocal runs on the default-unit value (`8 / 100` litres per km).
- A formula literal `{mile | gallon}` means that registered unit, so the number is the mile-per-gallon count that `k / value` expects.

## Decisions

1. **One category.** Both formulas are units of `:consumption` (`formula: "volume | length"`, `default: "L | km"`, `additive: false`). There is no `inverse_of:` link.
2. **Registration gate.** `add_unit/4` accepts a formula when its dimension is the exact inverse of the category dimension (every exponent negated, both dimensions non-empty) and `conversion_at_zero` is `division by zero`. The category must already be non-additive. A linear conversion of an inverse formula keeps today's dimension error. A reciprocal whose dimension is not that inverse keeps the dimension error. `per > 1` on the inverse formula keeps the dimension error (`mile | 100 gallon`).
3. **Duplicate.** A second unit whose formula monomial matches that inverse unit is `unit '<name>' has the same scale as 'mile | gallon'`, including a spacing variant (`mile|gallon`).
4. **Conversion.** `unit:` and `convert/2` reduce the source to the category default, then apply the target's `from_default`. A scaled source whose monomial is the default monomial contributes `value / per` once. The target's stored inverse already yields the target count, so `per` is not applied again. `0` on either side is `division by zero`.
5. **Literal.** A braced or unbraced formula that matches exactly one registered inverse unit evaluates as that unit: value `8` means eight miles per gallon, not a raw length-per-volume quantity. The result of `unit: "mile | gallon"` inspects as `mile | gallon` and converts back through the same `k`.
6. **Unchanged paths.** `L | 100 km` with `unit: "L | km"` stays `0.08`. Opaque `L100km` ↔ `mpg` with `235.215 / value` stays. `1 / 8 {L | 100 km}` stays `12.5 km | L`.

## Assumptions

- The worked example uses gallon `value * 3.785411784` and mile `value * 1.609344`, and `mile | gallon` converts with `"3.785411784 / 1.609344 / value"`. Elex evaluates that string left to right at Decimal precision 34, so `k` is rounded before dividing by the default value. `k / 0.08` and `(k / 8) * 100` are the same value, `29.40182291666666666666666666666666`. A single division `3.785411784 / (1.609344 * 0.08)` rounds the repeating 6 up to `…667`; that is not how the conversion string runs. Inverting the step 1 quantity is one unit in the last place above 8.
- `validate/3` does not take `unit:`. Type checks use `validate/2`.
- Adding the two units uses the existing non-additive error `cannot use non-additive consumption with '+'`.
- Symbol aliases keep today's rules. This design does not add alias cases.
- `convert/2` matches `unit:` for the same target string.

## Non-goals

- `inverse_of:` or any other cross-category option
- Inverting whenever two dimensions are opposites, with no reciprocal conversion string
- Treating `1 / value` as "invert, then apply component factors"
- A denominator coefficient on the inverse formula
- Changing opaque `mpg` ↔ `L100km`
- Registering `mile | gallon` on a length-per-volume category with a linear component conversion (that registration stays valid and does not by itself convert from `L | 100 km`)

## Public surface

`Catalog.add_unit/4` gains one acceptance: an inverse-dimension formula with a reciprocal conversion on a non-additive category. `evaluate/3` `unit:` and `convert/2` convert between that unit and other units of the category. Formula literals that match the inverse unit are that unit. Compatibility: **additive**. Who can call: any caller with a context. No actor or tenant.

- Valid: `Catalog.add_unit(catalog, :consumption, "mile | gallon", "3.785411784 / 1.609344 / value")` → `{:ok, catalog}`
- Invalid: `Catalog.add_unit(catalog, :consumption, "mile | gallon", "value")` → `{:error, "formula 'mile | gallon' does not match the category dimension"}`

## User flows

### Flow 1: Registration

**Actor:** library caller

**Precondition:** `L` and `gallon` are volume units (`gallon` is `value * 3.785411784`). `km` and `mile` are length units (`mile` is `value * 1.609344`). `:consumption` is `formula: "volume | length"`, `default: "L | km"`, `additive: false`, and `L | km` is registered with `"value"`.

**Steps:**

1. Register `L | 100 km` with `"value / 100"` → `{:ok, catalog}`
2. Register `mile | gallon` with `"3.785411784 / 1.609344 / value"` → `{:ok, catalog}`
3. `Context.put_units/2` → `{:ok, context}`

**Error paths:**

- `mile | gallon` with `"value"` → `formula 'mile | gallon' does not match the category dimension`
- The same reciprocal on `additive: true` → `reciprocal conversion for 'mile | gallon' is not allowed on additive category :consumption`
- `kg` with `"2 / value"` → `formula 'kg' does not match the category dimension`
- `mile | 100 gallon` with the reciprocal → `formula 'mile | 100 gallon' does not match the category dimension`
- `mile|gallon` after `mile | gallon` → `unit 'mile|gallon' has the same scale as 'mile | gallon'`

### Flow 2: Convert both ways

**Actor:** library caller

**Precondition:** Flow 1 context. `k = 3.785411784 / 1.609344`, evaluated left to right at Decimal precision 34. Both directions below equal `29.40182291666666666666666666666666`.

**Steps:**

1. `evaluate("8 {L | 100 km}", ctx, unit: "mile | gallon")` → `#Elex.Quantity<29.40182291666666666666666666666666 mile | gallon>`
2. That result with `unit: "L | 100 km"` → `#Elex.Quantity<8.000000000000000000000000000000001 L | 100 km>`
3. `evaluate("8 {L | 100 km}", ctx, unit: "L | km")` → `#Elex.Quantity<0.08 L | km>`
4. `evaluate("8 {mile | gallon}", ctx, unit: "L | 100 km")` → `#Elex.Quantity<29.40182291666666666666666666666666 L | 100 km>`
5. `evaluate("8 mile | gallon", ctx, unit: "L | 100 km")` → the same quantity as step 4
6. `evaluate("convert(8 {L | 100 km}, \"mile | gallon\")", ctx)` → the same quantity as step 1
7. `validate("8 {L | 100 km}", ctx)` and `validate("8 {mile | gallon}", ctx)` both return the consumption dimension

**Error paths:**

- `evaluate("0 {L | 100 km}", ctx, unit: "mile | gallon")` → `division by zero`
- `evaluate("0 {mile | gallon}", ctx, unit: "L | 100 km")` → `division by zero`
- `evaluate("8 {L | 100 km} + 1 {mile | gallon}", ctx)` and `validate` of that expression → `cannot use non-additive consumption with '+'`

## Architecture

Registration stays in `Catalog.add_unit/4`. The dimension check allows the exact inverse through only when the parsed conversion is a reciprocal and the category is non-additive. Component-scale comparison already skips reciprocals.

`unit:` stays in the evaluator. For a target or source that is a registered inverse unit, convert through the category default with the stored `to_default` / `from_default` asts. Formula quantities of `L | 100 km` still carry `per` on the default monomial. Inverse-unit quantities carry the component monomial (`mile` over `gallon`) and `per` 1. The reciprocal constant is found by matching that monomial to the one registered inverse unit.

The parser already builds braced and unbraced pipe formulas. The literal path resolves a match to the registered inverse unit before evaluation treats the value as a raw component quantity.

## Data flow

1. `8 {L | 100 km}` is value `8`, monomial `L` over `km`, `per` 100.
2. Default value is `8 / 100` = `0.08` litres per km.
3. `from_default` of `mile | gallon` is `k / 0.08`.
4. The result monomial is `mile` over `gallon`, `per` 1.
5. The reverse applies `to_default` (`k / value`) and then `L | 100 km`'s `from_default` (`value * 100`).

## Error handling

| Situation | Message |
|---|---|
| Inverse formula, linear conversion | `formula 'mile \| gallon' does not match the category dimension` |
| Inverse formula, `per > 1` | `formula 'mile \| 100 gallon' does not match the category dimension` |
| Reciprocal, dimension is not the inverse | `formula 'kg' does not match the category dimension` |
| Reciprocal on an additive category | `reciprocal conversion for 'mile \| gallon' is not allowed on additive category :consumption` |
| Second unit, same inverse monomial | `unit 'mile\|gallon' has the same scale as 'mile \| gallon'` |
| Zero through the reciprocal | `division by zero` |
| Addition | `cannot use non-additive consumption with '+'` |

## Testing strategy

ExUnit. No LiveView. One test file, `test/elex/units/inverse_conversion_test.exs`.

| Flow | Test |
|---|---|
| Flow 1 steps 1–3 and every error path | registration tests in that file |
| Flow 2 steps 1–7 and every error path | evaluate and validate tests in that file |

Domain skill: `test-driven-development`.

## Batch 1: Inverse formula on a non-additive category

**Status:** done

**Scope:** registration, `unit:` / `convert/2`, literals, guides. Excludes: a new category option, opaque `mpg` changes.

### Task 1.1: Accept an inverse reciprocal

**Status:** done — `7e1cfbb` (+ review fixes: `9c9db40`)

- Files: Modify `lib/elex/units/catalog.ex`; Create `test/elex/units/inverse_conversion_test.exs`
- TDD: yes
- UI flow: Flow 1
- Verify: `mix test test/elex/units/inverse_conversion_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 1 steps 1–3 succeed, including `put_units`
  - Flow 1 error paths return the messages in the error table
- Out of scope: `evaluate`, `unit:`, literals

### Task 1.2: Convert through the category default once

**Status:** done — `d29f4f5`

- Files: Modify `lib/elex/evaluator.ex`; Test `test/elex/units/inverse_conversion_test.exs`
- TDD: yes
- UI flow: Flow 2 steps 1–3 and the zero error paths
- Verify: `mix test test/elex/units/inverse_conversion_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 2 steps 1–3 match the quantities above
  - Step 2 converts the step 1 result
  - Both zero paths return `division by zero`
- Out of scope: formula literals `8 {mile | gallon}`, guides

### Task 1.3: Bind the inverse literal and convert back

**Status:** done — `9012338`

- Files: Modify `lib/elex/evaluator.ex` and `lib/elex/parser.ex` only if the literal is resolved there; Test `test/elex/units/inverse_conversion_test.exs`
- TDD: yes
- UI flow: Flow 2 steps 4–7 and the addition error path
- Verify: `mix test test/elex/units/inverse_conversion_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 2 steps 4–6 match step 1's value on the `L | 100 km` result, and step 6 matches step 1
  - Both `validate/2` calls return the consumption dimension
  - Addition returns `cannot use non-additive consumption with '+'` from `evaluate` and `validate`
- Out of scope: registration rules, guides

### Task 1.4: Guides and the denominator-scale non-goal

**Status:** done — `9fc5cc7`

- Files: Modify `guides/units.md`, `CHANGELOG.md`, `docs/design/denominator-scale/index.md`
- TDD: no
- UI flow: N/A
- Verify: `mix test test/elex/units/inverse_conversion_test.exs`
- Domain skills: N/A
- Acceptance:
  - `guides/units.md` shows the non-additive consumption category, the `k / value` registration, and `8 {L | 100 km}` with `unit: "mile | gallon"`
  - `CHANGELOG.md` `[Unreleased]` records the additive acceptance
  - The denominator-scale non-goal that forbids this `unit:` conversion points here instead
- Out of scope: version bump, code changes
