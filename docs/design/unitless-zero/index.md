# Unitless zero next to quantities

Allow a **literal** `0` with no unit when comparing or combining with an **additive** quantity. `10cm > 0` validates and evaluates; `10cm > 1` and `1C > 0` stay errors.

Follow-on to [units](../units/index.md). User flows below are canonical.

## Implementation status
**Status:** in progress

## Problem and constraints

`validate("10cm > 0", ctx)` is `cannot compare length and number`. Callers write `width > 0`, `if(width > 0, width, 0)`, `clamp(width, 0, 10cm)`. For additive quantities, `0` is the unique zero of that dimension (`0 cm` = `0 m`). Elex already type-checks statically, so only **literal** zeros can be special-cased without weakening `10cm > 1`.

**Constraints:**

- Opt-in catalogs unchanged; no new Elixir API
- Validate and evaluate stay in sync
- Non-additive categories (`additive: false`) keep mixed number/quantity as an error (`0C ≠ 0F ≠ 0K`)
- `+` / `-` stay `cannot add length and number` (including `10cm + 0`)

## User flows

Actor is always a **library caller**. Catalogs are test/caller fixtures.

### Flow 1: Compare a quantity to literal 0

**Precondition:** length catalog (`m`, `cm`, `mm`)

**Steps:**

1. `validate("10cm > 0", ctx)` → `{:ok, :boolean}`
2. `evaluate("10cm > 0", ctx)` → `{:ok, true}`
3. `evaluate("10cm == 0", ctx)` → `{:ok, false}`
4. `evaluate("10cm < 0", ctx)` → `{:ok, false}`
5. `evaluate("0 < 10cm", ctx)` → `{:ok, true}` (either operand)
6. `evaluate("0cm == 0", ctx)` → `{:ok, true}`
7. `0.0`, `0.00`, `0e0`, `-0`, `(0)` behave the same as `0`

**Error paths:**

- `10cm > 1` / `10cm > 0.1` → `cannot compare length and number`
- `10cm > count` when `count` is a number variable → same error
- `10cm > (1 - 1)` → same error (computed zero is not a literal)

### Flow 2: Point functions

**Precondition:** same length catalog

**Steps:**

1. `min(10cm, 0)` → `#Elex.Quantity<0 cm>`
2. `min(0, 10cm)` → `#Elex.Quantity<0 cm>` (unit from the quantity argument)
3. `max(10cm, 0)` → `#Elex.Quantity<10 cm>`
4. `clamp(-1cm, 0, 10cm)` → `#Elex.Quantity<0 cm>`
5. `between(5cm, 0, 10cm)` → `true`
6. `min(0, 10cm, 5mm)` → `#Elex.Quantity<0 cm>` (align into first quantity’s unit, then min)

**Error paths:**

- `min(10cm, 1)` → `cannot mix number and length`
- `min(10cm, 0, 1kg)` → `cannot mix length and mass`

### Flow 3: `if` / `coalesce`

**Precondition:** length catalog; `width` is `{10, "cm"}` with `category: :length` where used

**Steps:**

1. `if(true, 10cm, 0)` → `#Elex.Quantity<10 cm>`
2. `if(false, 10cm, 0)` → `#Elex.Quantity<0 cm>`
3. `if(width > 0, width, 0)` → `#Elex.Quantity<10 cm>`
4. `coalesce(null, 0, 10cm)` → `#Elex.Quantity<0 cm>` (first non-null is 0, wrapped in the quantity’s unit)
5. `coalesce(null, 10cm, 0)` → `#Elex.Quantity<10 cm>`

**Error paths:**

- `if(true, 10cm, 1)` → `if branches must have the same type, got length and number`

### Flow 4: Still rejected

**Steps (unchanged behaviour):**

1. `10cm + 0` / `0 + 10cm` → `cannot add length and number`
2. `1C > 0` / `min(1C, 0)` / `if(true, 1C, 0)` → type error (non-additive)
3. `min(0, 1)` → `#Decimal<0>`
4. `10cm * 0` → `#Elex.Quantity<0 cm>` (scalar multiply, already allowed)

## Decisions

1. **Scope:** comparisons (`<`, `>`, `<=`, `>=`, `==`, `!=`) and multi-arg `:point` functions (`min`, `max`, `clamp`, `between`, `if`, `coalesce`). Not `+` / `-`.
2. **Literal zeros only:** AST is a `Decimal` with `Decimal.compare(d, 0) == :eq`, or unary minus of that (`{:-, operand}` — not binary `{:-, [left, right]}`). Parentheses unwrap, so `(0)` is a `Decimal`. Variables and `1 - 1` stay type errors.
3. **Non-additive rejected:** unitless 0 is not unique across C/F/K. Existing messages (`cannot compare temperature and number`, `cannot mix number and temperature`).
4. **Shared helper:** detect literal zero in the validator; treat it as the other operand’s additive dimension. Evaluate wraps a `Decimal` 0 as `0` of the quantity’s unit in `compare` and `align_to_unit`. One rule for operators, builtins, and custom functions that use `same_numeric_type/2`.
5. **Result unit:** existing first-quantity-wins align. `min(0, 10cm)` is `0 cm`. `min(0, 0)` stays a number.

## Assumptions

- Either operand may be the literal 0 (`0 < 10cm` and `10cm > 0`).
- `0.0`, `0.00`, `0e0` count; unary-minus chains of a literal 0 count (`--0`).
- Error copy is unchanged (no new “unitless zero” message).
- `same_numeric_type/2` inherits the rule, so a custom `:additive` function that uses it also accepts literal 0 next to an additive quantity. Language `+` / `-` do not use that helper and stay rejected.
- Custom functions that check types themselves do not inherit unless they call the helper.
- Evaluate still rejects non-additive quantity vs `Decimal` 0 if validate is skipped (`evaluate!`).
- Ash `expected_type: :length` on an expression whose result is boolean (`width > 0`) is unchanged (still a boolean, not a length).

## Non-goals

- Unitless 0 in `+` / `-` (`10cm + 0`)
- Runtime zeros (variables, `1 - 1`)
- Unitless 0 on non-additive categories
- Allowing any number next to a quantity at validate and failing at evaluate
- Parser rewrite of `0` into a unitful literal
- New Elixir functions or options

## Public surface

Expression `validate` / `evaluate` for comparisons and `:point` functions. `Elex.Validator.same_numeric_type/2` treats a literal 0 as compatible with an additive quantity.

- Who can call: anyone with a catalog (same as today)
- Compatibility: **additive** (today these are errors; they become valid)
- Valid: `evaluate("10cm > 0", ctx)` → `{:ok, true}`
- Invalid: `evaluate("10cm > 1", ctx)` → `cannot compare length and number`
- No new Elixir functions. `+` / `-` unchanged.

## Architecture

Literal-zero helper on the validator (AST only). Comparison and equality use it when one side is `:decimal` and the other is an additive dimension. `same_numeric_type/2` skips literal-zero arguments when unifying with an additive quantity type; remaining zeros with no quantity stay `:decimal`. `if` / `coalesce` unify a literal-zero branch/arg with the other additive quantity type.

Evaluator: `compare/3` and `==` / `!=` wrap `Decimal` 0 as `Quantity{value: 0, unit: other.unit}` when `other` is an additive quantity. `align_to_unit/3` does the same when the target unit is additive so `min` / `max` / `clamp` / `between` (via `align_quantity_args`) and `if` / `coalesce` (`evaluate_call`) wrap before `call/1`. Non-additive target: leave the decimal unwrapped so existing type/mix errors still fire.

No parser or catalog changes.

## Data flow

1. Parse: `0` is `#Decimal<0>`; `-0` is `{:-, #Decimal<0>}`.
2. Validate: literal 0 + additive quantity → boolean (compare) or the quantity’s dimension (functions / `if` / `coalesce`).
3. Evaluate: wrap 0 into the quantity unit, then existing compare or first-quantity align.

## Error handling

Keep current messages. `10cm > 1` → `cannot compare length and number`. `min(10cm, 1)` → `cannot mix number and length`. `if(true, 10cm, 1)` → branches must have the same type. Non-additive `1C > 0` uses the same compare-number message as `1C > 1`. `10cm + 0` unchanged.

## Testing strategy

Library-only ExUnit and unit TDD (`test-driven-development`). No UI flow tests. Fixtures already in `test/elex/units/*_test.exs` (length in `functions_test` / `arithmetic_test`, temperature in `temperature_test`).

| Flow | File | Proves |
|---|---|---|
| 1 | `test/elex/units/functions_test.exs`, `test/elex/units/arithmetic_test.exs` | `10cm > 0` validates and evaluates; either side; `0.0` / `-0`; `10cm > 1` still errors |
| 2 | `test/elex/units/functions_test.exs` | `min` / `max` / `clamp` / `between` wrap 0; first-quantity unit; `min(10cm, 1)` still errors |
| 3 | `test/elex/units/functions_test.exs` | `if` / `coalesce` wrap 0; `if(..., 10cm, 1)` still errors |
| 4 | `test/elex/units/arithmetic_test.exs`, `test/elex/units/temperature_test.exs` | `10cm + 0` still errors; `1C > 0` / `min(1C, 0)` still errors; `10cm * 0` unchanged |

Guides: `guides/units.md` (comparisons, functions, non-additive), `guides/functions.md` (`clamp` / `between` / `if`). `CHANGELOG.md` Unreleased. `lib/elex/function.ex` `:point` / `same_numeric_type` note.

## Batch 1: Unitless zero
**Status:** in progress
**Scope:** validate + evaluate + guides. Excludes: `+` / `-` identity, non-additive 0, runtime zeros.

### Task 1.1: Comparison operators
**Status:** done — `cc6091f`

- Files: Modify `lib/elex/validator.ex`, `lib/elex/evaluator.ex`; Test `test/elex/units/functions_test.exs`, `test/elex/units/arithmetic_test.exs`, `test/elex/units/temperature_test.exs`
- TDD: yes
- UI flow: N/A
- Verify: `mix test test/elex/units/functions_test.exs test/elex/units/arithmetic_test.exs test/elex/units/temperature_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - `validate("10cm > 0")` is `:boolean`; `evaluate` of `10cm > 0` / `==` / `<` / `0 < 10cm` / `0cm == 0` matches Flow 1
  - `0.0`, `-0` work; `10cm > 1` and `10cm > (1 - 1)` still `cannot compare length and number`
  - `1C > 0` still a type error
- Out of scope: `min` / `if` / `+`

### Task 1.2: `min` / `max` / `clamp` / `between`
**Status:** in progress

- Files: Modify `lib/elex/validator.ex` (`same_numeric_type/2`), `lib/elex/evaluator.ex` (`align_to_unit/3`); Test `test/elex/units/functions_test.exs`, `test/elex/units/temperature_test.exs`
- TDD: yes
- UI flow: N/A
- Verify: `mix test test/elex/units/functions_test.exs test/elex/units/temperature_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 2 steps 1–6
  - `min(10cm, 1)` and `min(10cm, 0, 1kg)` still error
  - `min(1C, 0)` still a type error
- Out of scope: `if` / `coalesce`; comparison ops (Task 1.1)

### Task 1.3: `if` / `coalesce`
**Status:** pending

- Files: Modify `lib/elex/functions/if.ex`, `lib/elex/functions/coalesce.ex` (and validator unify helper if shared); Test `test/elex/units/functions_test.exs`, `test/elex/units/temperature_test.exs`
- TDD: yes
- UI flow: N/A
- Verify: `mix test test/elex/units/functions_test.exs test/elex/units/temperature_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 3 steps 1–5
  - `if(true, 10cm, 1)` still type-mismatched branches
  - `if(true, 1C, 0)` still a type error
- Out of scope: `min` / `clamp`; `+` / `-`

### Task 1.4: Guides and changelog
**Status:** pending

- Files: Modify `guides/units.md`, `guides/functions.md`, `CHANGELOG.md`, `lib/elex/function.ex`
- TDD: no
- UI flow: N/A
- Verify: `mix test test/elex/units/functions_test.exs test/elex/units/arithmetic_test.exs test/elex/units/temperature_test.exs`
- Acceptance:
  - Units guide states literal 0 is allowed in comparisons and `:point` functions on additive categories; `10cm + 0` and `1C > 0` are not
  - Functions guide examples include `clamp(width, 0, 10cm)` / `if(width > 0, width, 0)`
  - Unreleased changelog records the additive language change
- Out of scope: code behaviour (Tasks 1.1–1.3)
