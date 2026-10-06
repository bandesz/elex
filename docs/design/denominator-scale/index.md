# Denominator scale

Registered units may include one fixed denominator coefficient, so `8 {L | 100 km}` is 8 litres per 100 kilometres: value `8`, dimension volume per length, equal to `0.08 {L | km}`.

Follow-on to [units](../units/index.md). User flows in [user-flows.md](user-flows.md) are canonical.

## Implementation status

**Status:** in progress — implementation review
**Review fixes:** `bafca77`, `f366611`

## Problem and constraints

Fuel consumption is written as litres per 100 km so the number stays human-sized. A unit today is only a map of symbols to exponents, so `L | 100 km` is an invalid formula. Callers can register an opaque name such as `L100km`, or write `8L / 100km` and get `0.08 L | km`. Neither keeps both the value `8` and a unit that cancels against kilometres.

**Constraints:**

- Opt-in catalogs. Elex still ships no unit system.
- The coefficient is allowed only on a **registered** unit. `L | 50 km` is an unknown unit until that exact scale is registered.
- The conversion passed to `add_unit/4` must match the components divided by that coefficient. `add_unit/3` still means `"value"`, which fails the check for a scaled name.
- The category default stays the per-1 identity (`L | km`). A derived category still needs that identity unit.
- Arithmetic uses the scale. A result whose monomial and `per` are not a registered unit folds the scale into the value.
- Existing formulas keep the current `Formula.parse/1` success shape.

## Decisions

1. **Representation:** `%Elex.Unit{monomial, per}`. `per` is a positive integer and defaults to `1`. The quantity is `(value / per)` in that monomial. `8` with monomial `L^1 km^-1` and `per` 100 is `0.08 L | km`.
2. **Registration gate:** a formula with `per > 1` may appear in a literal, `unit:`, `convert/2`, or `add_unit/2` only when a registered unit has that monomial and that `per`. Spacing is not significant (`L|100km` matches registered `L | 100 km`). `add_unit/2` still resolves the registered name through `Catalog.canonical_name/2`, so the string must be the canonical name or an existing symbol alias.
3. **Explicit conversion:** `add_unit(catalog, :consumption, "L | 100 km", "value / 100")`. Expected scale is the existing component factor divided by `per`. A mismatch uses the current component-scale error.
4. **One denominator coefficient:** an integer `>= 2`, no leading zero, written by juxtaposition before one denominator symbol (`100 km`, `L|100km`). `L | 100 * km` and `L | km * 100` are invalid formulas. The existing numerator `1` in `1 | s` stays a two-tuple. `1 | 100 s` is `per` 100 on `s^-1`. An unbraced literal `8 L | 100 km` is that same unit. After the suffix, `* 2` multiplies the quantity. `* km` stays the existing unbraced-continuation error.
5. **Keep or fold:** scalar multiply and unary minus keep the unit. Addition converts into the left unit, including `per`. After `*` or `/` of two quantities, if the combined monomial and integer `per` equal a registered unit, keep that `per` and the un-normalized value. Otherwise `per` becomes `1` and the value becomes the physical magnitude. Two consumptions therefore become `0.0024 L^2 | km^2`. Cancelling the denominator against `100 km` becomes `8 L`.
6. **Identity:** a unit counts as the base-hub identity only when its formula parses with `per` 1. `default: "L | 100 km"` is rejected at `add_category`.
7. **`add_unit/2` error copy:** an unregistered formula string keeps today's message `add_unit expects a registered unit symbol, got 'L | 50 km'`. The chat draft said "literal"; that wording stays reserved for a non-string argument.

## Assumptions

- `1 | 100 s` is a denominator coefficient and is usable once registered.
- A braced formula may still multiply denominator symbols (`{L | 100 km * m}` is `per` 100 on `L`, `km`, and `m`). The unbraced suffix stops after the one symbol that follows the coefficient.
- `validate("8 L | 50 km", ctx)` returns the same `unknown unit` error as `evaluate`.
- Aliases stay symbol-shaped. A caller may pass `aliases: ["L100km"]`. `L/100km` is not a legal alias.
- `Unit.new/1` on a monomial map sets `per` to `1`.
- `convertible?/3` and `compatible?/3` ignore `per`.
- Inspect sorts symbols as it does today and prints the coefficient after `|` when `per > 1`.

## Non-goals

- A coefficient written with `*` (`L | 100 * km`, `8 L | 100 * km`, `L | km * 100`)
- A slash inside a formula (`L/100km`)
- A numerator coefficient (`100 km | h`, `2 L | km`)
- Direct `unit:` between `L | 100 km` and `mile | gallon` unless `mile | gallon` is registered on that non-additive category with a reciprocal conversion. That registration is [inverse conversion](../inverse-conversion/index.md). Ordinary division stays `1 / 8 {L | 100 km}` → `12.5 km | L`
- A coefficient on a formula that was not registered
- Using a denominator-scale unit, or an alias of one, as a component of another formula (`L100km * h`, `L100km | 10 h`, `h | L100km`). The unit is only its registered name or a symbol alias of that whole unit. Multiplying quantities (`8 {L | 100 km} * 100 km`, `8 {L100km} * 1 {h}`) stays ordinary arithmetic
- Changing quantity inspect to insert `{}`

## Public surface

Expression literals, `unit:`, `convert/2`, and `add_unit/2` gain registered denominator coefficients. Compatibility: **additive**.

`%Elex.Unit{}` gains `per`, default `1`. `same?/2` compares monomial and `per`. Compatibility: **additive** (existing units compare as they do today).

`Formula.parse/1` and `Catalog.parse_formula/2` keep returning `{:ok, monomial}` when `per` is 1. A denominator coefficient returns `{:ok, monomial, per}`. Compatibility: **additive**.

`Unit.new/1` accepts a scaled formula and returns the struct. `Catalog.add_unit/4` rejects a scaled name whose conversion disagrees with `per`. `Catalog.add_category/3` rejects a `default:` that contains a coefficient.

Who can call: any caller with a context. No actor or tenant.

- Valid: `Unit.new("L | 100 km")` → `{:ok, %Elex.Unit{monomial: %{"L" => 1, "km" => -1}, per: 100}}`
- Valid: `evaluate("8 L | 100 km", ctx)` → quantity `8`, `per` 100, when that scaled unit is registered
- Valid: `evaluate("8 {L | 100 km}", ctx, unit: "L | km")` → quantity `0.08`, `per` 1, when that scaled unit is registered
- Invalid: `Formula.parse("L | 100 * km")` → `{:error, "invalid formula 'L | 100 * km'"}`
- Invalid: `evaluate("8 {L | 50 km}", ctx)` → `{:error, "unknown unit 'L | 50 km'"}` when that scale was not registered

## Architecture

`per` sits beside the monomial. Registration stores the caller's formula string as the canonical name. The scale check extends the existing component-scale comparison: expected conversion at 1 is `component_factor / per`. Callers of `Formula.parse/1` that match only `{:ok, monomial}` must treat a third element as `per` (default 1). A 3-tuple must not satisfy an identity match.

`Catalog.parse_formula/2` returns `{:ok, monomial, per}` when the formula's monomial and `per` match one registered unit. When `per > 1` and nothing matches, it returns `unknown unit` with the caller's spelling. The expression parser accepts both success shapes; a 3-tuple is not a formula error. An unbraced suffix is `symbol | integer symbol` (optional spaces, optional `^` on the symbol). The integer and the symbol are juxtaposed. A `*` between them is `invalid formula`, not expression multiplication.

Evaluation builds `%Unit{per: per}`. `convert_to/3` converts the physical value (`value / per`) through the existing hub path, then multiplies by the target `per`. Quantity `*` and `/` combine monomials and pers, then keep or fold as in decision 5. When the monomials cancel to a number, the result is the ratio of the physical values (Flow 3 steps 6 and 13), not a unit. Comparisons and `:point` functions (`min`) reuse `convert_to/3`.

`add_unit/2` resolves the canonical name and then `Catalog.parse_formula/2`, so alias symbols expand and a matched denominator coefficient sets `per`.

## Data flow

1. `Formula.parse("L | 100 km")` → `{:ok, %{"L" => 1, "km" => -1}, 100}`.
2. `add_unit/4` checks dimension, then `component_factor / per` against the conversion.
3. A braced or unbraced literal calls `Catalog.parse_formula/2`. A match becomes `{:unit, decimal, formula}` and evaluates to a quantity with that `per`.
4. `unit:` / `convert/2` parse the target the same way and `convert_to/3` rescales.
5. Arithmetic combines physical magnitudes and folds unless the result is a registered scaled unit.

## Error handling

| Situation | Message |
|---|---|
| Conversion disagrees with `per` | `unit 'L \| 100 km' conversion does not match the scale of its component units` |
| Second unit, same monomial and same `per` (a different `per` is a different unit) | `unit 'L\|100km' has the same scale as 'L \| 100 km'` |
| Scaled name on the wrong category | `formula 'L \| 100 km' does not match the category dimension` |
| `default:` contains a coefficient | `default unit 'L \| 100 km' cannot include a denominator coefficient` |
| Derived category lacks a per-1 identity unit | `derived category :consumption needs a registered unit matching the base hubs (e.g. "L \| km")` |
| Unregistered coefficient in an expression | `unknown unit 'L \| 50 km'` |
| Scaled unit or its alias inside another formula | `unit 'L100km' cannot be used inside another formula` |
| Unregistered formula string in `add_unit/2` | `add_unit expects a registered unit symbol, got 'L \| 50 km'` |
| Numerator coefficient, `per` of 0 or 1, leading zero, second integer, `*` next to the coefficient | `invalid formula '<source>'` |
| Unbraced suffix continues with `* km` | `unbraced pipe suffixes cannot continue with '* km'; write a power on the denominator or a braced formula` |
| Quantity plus a number | `cannot add consumption and number` |
| Divide by a zero quantity | `division by zero` |

## Testing strategy

Library-only ExUnit and unit TDD (`test-driven-development`). No UI flow tests.

| Flow | File | Proves |
|---|---|---|
| 4 | `test/elex/units/formula_test.exs` | Parse success tuples and invalid formulas |
| 2 (unit struct) | `test/elex/units/unit_test.exs` | `per`, inspect, `same?/2`, `convertible?/3` ignores `per` |
| 1 | `test/elex/units/denominator_scale_test.exs` | Registration success and every Flow 1 error |
| 2, 3 | `test/elex/units/denominator_scale_test.exs` | Braced and unbraced literals, convert, arithmetic, errors |

Guides: `guides/units.md` (new subsection under Derived categories). `CHANGELOG.md` Unreleased.

Coverage (implementation):

- [ ] Flow 1 registration and error paths
- [ ] Flow 2 literal, inspect, convert, validate, `add_unit/2`, unknown unit
- [ ] Flow 3 arithmetic, fold, inversion, zero, negation
- [ ] Flow 4 parse tuples and rejected formulas

## Batch 1: Parse and print

**Status:** done

**Scope:** formula grammar and `%Elex.Unit{}`. Excludes: catalog checks, expressions.

### Task 1.1: Denominator coefficient in `Formula.parse/1`

**Status:** done — `fec276d`

- Files: Modify `lib/elex/units/formula.ex`; Test `test/elex/units/formula_test.exs`
- TDD: yes
- UI flow: Flow 4
- Verify: `mix test test/elex/units/formula_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 4 steps 1–4
  - Flow 4 error paths (`100 km | h`, `L | 100 * km`, `L | km * 100`, `L | 1 km`, `L | 0 km`, `L | 01 km`, `L | 100 km * 2`)
  - `Formula.parse("m | s^2")` and `Formula.parse("1 | s")` stay two-tuples
- Out of scope: `Unit` struct, catalog, evaluate

### Task 1.2: `per` on `%Elex.Unit{}`

**Status:** done — `dafec31`

- Files: Modify `lib/elex/unit.ex`; Test `test/elex/units/unit_test.exs`
- TDD: yes
- UI flow: Flow 2 step 1 (unit inspect only)
- Verify: `mix test test/elex/units/unit_test.exs test/elex/units/formula_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - `Unit.new("L | 100 km")` → `{:ok, %Elex.Unit{monomial: %{"L" => 1, "km" => -1}, per: 100}}`
  - `Unit.new(%{"m" => 1})` has `per` 1
  - `same?/2` is true only when monomial and `per` match
  - `inspect` of that unit is `#Elex.Unit<L | 100 km>`; `inspect` of `L | km` is `#Elex.Unit<L | km>`
  - Existing `#Elex.Unit<m | s>` inspect is unchanged
  - `convertible?/3` is true for the same dimension with different `per`
- Out of scope: registration, evaluate

## Batch 2: Registration

**Status:** done

**Scope:** catalog checks for a scaled name. Excludes: expression evaluation.

### Task 2.1: Conversion must match `per`

**Status:** done — `404ec66`

- Files: Modify `lib/elex/units/catalog.ex`; Create `test/elex/units/denominator_scale_test.exs`
- TDD: yes
- UI flow: Flow 1 steps 1–3 and the conversion, millilitre, and dimension error paths
- Verify: `mix test test/elex/units/denominator_scale_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 1 steps 1–3 succeed
  - `"value / 50"` and an omitted conversion for `"L | 100 km"` return `unit 'L | 100 km' conversion does not match the scale of its component units`
  - `"mL | 100 km"` with `"value / 100"` returns that scale error for `'mL | 100 km'`
  - Registering `"L | 100 km"` on `:length` returns `formula 'L | 100 km' does not match the category dimension`
- Out of scope: `default:` rejection, duplicate scale, `put_units`, evaluate

### Task 2.2: Default, identity, and duplicate scale

**Status:** done — `39bd590`

- Files: Modify `lib/elex/units/catalog.ex`; Test `test/elex/units/denominator_scale_test.exs`
- TDD: yes
- UI flow: Flow 1 remaining error paths
- Verify: `mix test test/elex/units/denominator_scale_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - `default: "L | 100 km"` → `default unit 'L | 100 km' cannot include a denominator coefficient`
  - `:consumption` with `default: "cons"`, registered units `"cons"` (`"value"`) and `"L | 100 km"` (`"value / 100"`), and no `"L | km"`, then `put_units` → `derived category :consumption needs a registered unit matching the base hubs (e.g. "L | km")`
  - Registering `"L|100km"` after `"L | 100 km"` → `unit 'L|100km' has the same scale as 'L | 100 km'`
  - Registering `"L | 50 km"` with `"value / 50"` after `"L | 100 km"` → `{:ok, catalog}`
  - Flow 1 step 4 succeeds when `L | km` and `L | 100 km` are both registered
- Out of scope: expression literals

## Batch 3: Expressions

**Status:** done

**Scope:** literals, conversion, arithmetic. Excludes: guides.

### Task 3.1: Literal, validate, and `add_unit/2`

**Status:** done — `beb6c9a`

- Files: Modify `lib/elex/parser.ex`, `lib/elex/units/catalog.ex`, `lib/elex/evaluator.ex`, `lib/elex/validator.ex` (only if validate does not already surface the parse error); Test `test/elex/units/denominator_scale_test.exs`
- TDD: yes
- UI flow: Flow 2 steps 1, 2, 7, 8, 9, 10, 11, 12; Flow 3 steps 11 and 12; Flow 2 error paths for unknown unit, `*`, unbraced continuation, and `add_unit/2`
- Verify: `mix test test/elex/units/denominator_scale_test.exs test/elex/units/parser_test.exs test/elex/units/add_unit_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 2 steps 1, 2, 7, 8, 9, 10, 11, and 12
  - Flow 3 steps 11 and 12 (`0` and unary minus keep `L | 100 km`)
  - `evaluate` and `validate` of `8 {L | 50 km}` and `evaluate` of `8 L | 50 km` return `unknown unit 'L | 50 km'`
  - `8 L | 100 * km` and `8 {L | 100 * km}` return `invalid formula 'L | 100 * km'`
  - `8 L | 100 km * km` returns `unbraced pipe suffixes cannot continue with '* km'; write a power on the denominator or a braced formula`
  - `add_unit(8, "L | 50 km")` returns `add_unit expects a registered unit symbol, got 'L | 50 km'`
- Out of scope: `unit:` / `convert`, addition, multiplication

### Task 3.2: `unit:` and `convert/2`

**Status:** done — `b3e97c8`

- Files: Modify `lib/elex/evaluator.ex`; Test `test/elex/units/denominator_scale_test.exs`
- TDD: yes
- UI flow: Flow 2 steps 3–6 and the `unit: "L | 50 km"` error
- Verify: `mix test test/elex/units/denominator_scale_test.exs test/elex/units/component_conversion_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 2 steps 3, 4, 5, and 6
  - `unit: "L | 50 km"` → `unknown unit 'L | 50 km'`
- Out of scope: addition and multiplication

### Task 3.3: Addition, equality, and `min`

**Status:** done — `476372e`

- Files: Modify `lib/elex/evaluator.ex`; Test `test/elex/units/denominator_scale_test.exs`
- TDD: yes
- UI flow: Flow 3 steps 1, 2, 3, 7, 8 and the addition error path
- Verify: `mix test test/elex/units/denominator_scale_test.exs test/elex/units/arithmetic_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 3 steps 1, 2, 3, 7, and 8
  - `8 {L | 100 km} + 1` → `cannot add consumption and number`
- Out of scope: multiplication, fold, inversion

### Task 3.4: Multiply, divide, fold, and invert

**Status:** done — `a1a32fe`

- Files: Modify `lib/elex/evaluator.ex`; Test `test/elex/units/denominator_scale_test.exs`
- TDD: yes
- UI flow: Flow 3 steps 4, 5, 6, 9, 10, 13 and the division-by-zero error path
- Verify: `mix test test/elex/units/denominator_scale_test.exs test/elex/units/arithmetic_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 3 steps 4, 5, 6, 9, 10, and 13
  - `1 / 0 {L | 100 km}` → `division by zero`
- Out of scope: guides

## Batch 4: Docs

**Status:** done

**Scope:** guide and changelog. Excludes: behaviour changes.

### Task 4.1: Guide and changelog

**Status:** done — `7adcc7f`

- Files: Modify `guides/units.md`, `CHANGELOG.md`
- TDD: no
- UI flow: N/A
- Verify: `mix test test/elex/units/denominator_scale_test.exs test/elex/units/formula_test.exs test/elex/units/unit_test.exs`
- Acceptance:
  - Units guide, under Derived categories, shows registering `L | 100 km` with `"value / 100"`, the literals `8 {L | 100 km}` and `8 L | 100 km`, conversion to `L | km`, and `8 {L | 100 km} * 100 km` → `8 L`
  - The guide states that `L | 50 km` is an unknown unit until registered, and that the category default stays `L | km`
  - Unreleased changelog records the additive formula and `Unit` field
- Out of scope: code behaviour (Batches 1–3)
