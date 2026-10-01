# Percent values

A `%` suffix on a number literal is a percent. `50%` is the value 50 percent points, not a remainder and not a unit.

Behaviour is canonical in [user-flows.md](user-flows.md).

## Status

Complete.

## Implementation status

**Status:** complete
**Review fixes:** `53390a1`, `1840d44`

## Start here

| Doc | What it contains |
|---|---|
| [user-flows.md](user-flows.md) | Canonical caller journeys |
| This file | Decisions, public surface, architecture, tasks |

## Problem

Callers write rates as percents (`100 * 50%`, `10% + 20%`, `100cm * 50%`). The `%` remainder operator and `rem/2` were removed so `%` can be this suffix. Modulo is `mod/2`.

## Constraints

- `%` attaches to number literals only (`50%`, `50 %`, `-10%`, `1e2%`). Not `(10+20)%` and not `rate%`
- Works with or without a unit catalog
- A percent is not a catalog unit. `50% * 50%` stays a percent. It does not become a squared unit
- Any division that touches a percent is an error, including `100 / 50%`
- Percent `+` and `-` accept only percents. `100 + 10%` and `10% + 0` are errors
- A negative percent is a signed fraction. `-10%` is −10 percent points. `100% + -10%` is `90%`. Magnitudes outside `0..100` are valid
- `pow` follows the existing decimal algorithm on the fraction `points / 100`, then scales a percent result back by 100. `sqrt` rejects a percent

## Decisions

1. **Storage:** `%Elex.Percent{value: Decimal.t()}` stores percent points. `50%` stores `50`, the same way `10cm` stores `10`.
2. **Type:** validate returns the atom `:percent`. It is a scalar numeric type. It is not a unit category and must not be turned into an `%Elex.Dimension{}` or looked up in the catalog.
3. **Arithmetic:** addition and subtraction use points. Multiplication, scaling, and `pow` convert to a fraction only for the calculation. `p(a) * p(b) = p(a * b / 100)`. `n * p(a) = n * a / 100` as a decimal. A quantity keeps its unit and scales its magnitude the same way. Operators are commutative. `sqrt` does not.
4. **Literal zero:** the [unitless-zero](../unitless-zero/index.md) literal (`0`, `0.0`, `0e0`, `-0`, `(0)`, `--0`) is allowed next to a percent in comparisons and in `min`, `max`, `clamp`, `between`, `if`, and `coalesce`. It wraps as `Percent 0`. Variables and computed zeros do not count. `+` and `-` stay rejected.
5. **Messages for mixed numerics:** add, subtract, and compare use the quantity wording (`cannot add percent and number`, `cannot compare percent and number`), even though `:percent` is not a category. `got(:percent)` is `got percent`, not `got percent quantity`.
6. **`category:` message:** `validate("50%", ctx, category: :length)` is `length was expected, got percent`, the same shape as `length was expected, got number`. The chat wording `expression should return a valid length result` stays the quantity `unit:` mismatch, and is not used for a percent.
7. **`pow`:** integer powers stay exact (`pow(50%, 2)` is `25%`). A non-integer power uses the existing float path, scaling the decimal result back to percent points. `sqrt` rejects a percent on validate and evaluate with `sqrt function expects a number argument, got percent`.
8. **Invert:** any AST that contains `{:percent, _}` fails invert. Legal inverses such as `rate - 10%` and `price / 0.5` are deferred so invert cannot emit a division that uses a percent.
9. **No constructor helper:** callers build `%Elex.Percent{}`. There is no `Elex.percent/1`.

## Assumptions

- Inspect is `#Elex.Percent<50%>` and `#Elex.Percent<-10%>`. `evaluate("1e2%")` inspects as `#Elex.Percent<100%>`.
- `round(10.5%)` is `11%` and `round(-10.5%)` is `-11%`, because `Decimal.round/1` rounds half away from zero.
- `pow(0%, 0)` is `100%`, because decimal `pow(0, 0)` is `1`.
- `pow(-50%, 2)` is `25%` and `pow(-50%, 3)` is `-12.5%`.
- Trailing space after a percent literal is ignored.
- Autocomplete does not suggest `%`.
- Custom functions that validate with `Elex.Validator.same_numeric_type/2` accept a percent, and a literal `0` next to a percent, the same way they accept an additive quantity. Functions that check types themselves do not inherit that.
- `+` and `-` do not use `same_numeric_type/2` and still reject `10% + 0`.
- String functions, `convert`, `add_unit`, and `remove_unit` keep their existing errors, with `got percent`.
- `--10%` evaluates to `Percent 10` when the leading minus folds into the literal and a further unary minus remains. Tests do not need to cover a double minus unless a task lists it.
- `50%` is not a variable name. `extract_variables` returns only real names.

## Non-goals

- A postfix `%` on an arbitrary decimal (`(10+20)%`, `rate%`)
- Calculator sugar (`100 + 10%` meaning `110`)
- Any division that touches a percent
- `mod` on a percent
- `sqrt` of a percent
- Inverting an expression that contains a percent
- Suggesting `%` from autocomplete
- A percent unit in the catalog
- `Elex.percent/1`

## Public surface

Expressions that do not use `%` or `rem` are unchanged. Modulo is `mod/2` (sign follows the divisor). Who can call: any library caller.

| Surface | Contract |
|---|---|
| `%Elex.Percent{}` | Field `:value` is a `Decimal.t()` of percent points. Inspect `#Elex.Percent<50%>` |
| `Parser.parse/3` | `{:ok, {:percent, decimal}, :percent}`. `validate: false` returns type `nil`. `-10%` is `{:percent, Decimal.new("-10")}`. `-(50%)` is `{:-, {:percent, Decimal.new("50")}}` |
| `Elex.validate/3` | `{:ok, :percent}` for a percent result, with or without a catalog |
| `Elex.evaluate/3` | `{:ok, %Elex.Percent{}}` or, when a percent scales a number or quantity, the scaled decimal or quantity |
| `Elex.add_variable/4` | A `%Elex.Percent{value: Decimal}` infers type `:percent`. A non-decimal value is `variable 'rate' percent value must be a decimal` |
| `Elex.Labels` | `label(:percent)` is `"percent"`. `got(:percent)` is `"got percent"` |
| `Elex.Validator.same_numeric_type/2` | A percent unifies with a percent. A literal `0` unifies to `:percent` when another argument is a percent |
| `Elex.Inverter.invert/2` | AST containing `{:percent, _}` → `{:error, "cannot invert an expression that contains a percent"}` |
| `Elex.autocomplete/4` | `autocomplete("10%", 3, ctx)` → `suggestions: []`. Existing unit completion is unchanged |
| `Elex.AshValidation` | `expected_type: :percent` is a primitive type and does not need a catalog |
| `inc(value, rate)` | `value * (100% + rate)`. `inc(100, 10%)` is `110`. A quantity keeps its unit (`inc(100cm, 10%)` is `110cm`). A percent stays a percent (`inc(50%, 10%)` is `55%`). A non-percent rate is an error. A non-additive quantity is an error |
| `dec(value, rate)` | `value * (100% - rate)`. `dec(100, 10%)` is `90`. Same unit, percent, rate, and non-additive rules as `inc` |

**Valid:** `Elex.evaluate("100% > 0", Elex.new_context())` → `{:ok, true}`

**Invalid:** `Elex.evaluate("100% / 2", Elex.new_context())` → `{:error, "cannot divide with a percent"}`

`evaluate("50%", ctx, unit: "cm")` when `cm` is registered → `{:error, "cannot convert percent to a unit"}`.

`validate("50%", ctx, category: :length)` → `{:error, "length was expected, got percent"}`.

## Architecture

Percent-points struct, chosen over a stored fraction and over a synthetic catalog unit. A stored fraction would make `round(10.6%)` round `0.106` to `0`. A catalog unit would square under `*` and cancel under `/`.

Parser: `literal_number` already accepts an optional leading minus, fraction, and exponent. After that token, skip whitespace and, if the next character is `%`, emit `{:percent, decimal}` and consume the suffix. This runs even when no catalog is attached, and it runs before a unit suffix. The unary-minus alternative must not steal the minus of `-10%`, so that node stays a single percent literal. `-(50%)` still goes through unary minus because the parentheses are a grouped expression. A second `%`, or a unit glued after `%`, is left in the remainder and reported by the existing unexpected-token formatter.

Validator: `{:percent, _}` types as `:percent`. Clauses that treat every other atom as a unit category skip `:percent`. Add, subtract, and compare have explicit percent clauses for the messages in the flows. `/` errors with `cannot divide with a percent` when either operand’s type is `:percent`, before dimension math. `same_numeric_type/2` treats `:percent` as numeric and reuses the literal-zero helper, wrapping the result type as `:percent`.

Evaluator: `{:percent, decimal}` becomes `%Elex.Percent{value: normalized points}`. Binary `+` and `-` require two percents and add points. Binary `*` scales as in Decision 3, using `Decimal` division by 100. Unary minus of a percent negates the points. Comparisons order the points. Literal zero is wrapped to `Percent 0` before compare and before `:point` calls, matching quantity alignment. `pow` converts to a fraction, calls the existing decimal implementation, and multiplies a percent result by 100. `round`, `floor`, `ceil`, and `abs` operate on points and rewrap. `sqrt` and `mod` stay decimal-only.

`result_kind` of a percent is `percent`, so `unit:` says `cannot convert percent to a unit`. `match_optional_category/3` already labels non-dimensions via `Labels.label/1`, which yields `length was expected, got percent` once `:percent` is not a dimension.

Ash: add `:percent` to the primitive expected types so a catalog does not treat it as a category.

Invert: walk the AST; a `{:percent, _}` node raises the invert error before inversion.

## Data flow

1. Parse a number, optional whitespace, and `%` into `{:percent, decimal}`.
2. Validate that node as `:percent`. Do not consult the catalog.
3. Evaluate to `%Elex.Percent{}`. Operators and functions either keep a percent, scale a number or quantity, or return a boolean.
4. A literal `0` next to a percent becomes `Percent 0` at validate and evaluate. `+` and `-` never take that path.

## Error handling

Messages are fixed by the flows. Validate and evaluate use the same messages for type errors. `pow(0%, -1)` reuses the decimal function’s evaluation error unchanged. `sqrt(25%)` is `sqrt function expects a number argument, got percent`. Parse errors reuse `unexpected '…'`. No new error struct.

## Testing strategy

Library ExUnit and unit TDD (`test-driven-development`). No UI flow tests. Length catalogs in tests follow the setup in `test/elex/units/arithmetic_test.exs` (`m` default, `cm` = `value / 100`, `mm` = `value / 1000`).

| Flow | Test file | Task |
|---|---|---|
| 1 | `test/elex/expression/percent_literal_test.exs` | 1.2 |
| 2 | `test/elex/expression/percent_scale_test.exs` | 2.1 |
| 3 | `test/elex/expression/percent_arithmetic_test.exs` | 2.2 |
| 4 division | `test/elex/expression/percent_arithmetic_test.exs` | 2.3 |
| 4 `mod` | `test/elex/expression/percent_remainder_test.exs` | 3.3 |
| 5 | `test/elex/expression/percent_compare_test.exs` | 2.4 |
| 6 | `test/elex/expression/percent_minmax_test.exs` | 2.5 |
| 7 | `test/elex/expression/percent_if_test.exs` | 2.6 |
| 8 | `test/elex/expression/percent_round_test.exs` | 3.1 |
| 9 | `test/elex/expression/percent_pow_test.exs` | 3.2 |
| 10 | `test/elex/expression/percent_variable_test.exs` | 3.4 |
| 11 autocomplete | `test/elex/autocomplete_test.exs` | 3.7 |
| 11 invert | `test/elex/expression/inverter_test.exs` | 3.6 |
| 12 Ash | `test/elex/ash_validation_test.exs` | 3.5 |
| 12 `unit:` / `category:` | `test/elex/expression/percent_target_test.exs` | 3.8 |
| 13 `inc` / `dec` | `test/elex/expression/functions/inc_dec_test.exs` | — |

Struct inspect and labels are `test/elex/percent_test.exs` and `test/elex/labels_test.exs` (Task 1.1), not a caller flow.

Coverage checklist updates belong to `implementing-design` Phase 4, not a separate task.

- [x] Flow 1 literals and parse errors
- [x] Flow 2 scaling
- [x] Flow 3 percent arithmetic and mixed add/sub
- [x] Flow 4 division
- [x] Flow 4 `mod`
- [x] Flow 5 comparisons and literal zero
- [x] Flow 6 `min` / `max` / `clamp` / `between`
- [x] Flow 7 `if` / `coalesce`
- [x] Flow 8 `abs` / `round` / `floor` / `ceil`
- [x] Flow 9 `pow` / `sqrt`
- [x] Flow 10 variables
- [x] Flow 11 autocomplete and invert
- [x] Flow 12 Ash, `unit:`, and `category:`
- [x] Flow 13 `inc` / `dec` (`test/elex/expression/functions/inc_dec_test.exs`)

`convert(50%, "cm")` and `remove_unit(50%)` return their existing errors with `got percent` and are covered in `test/elex/expression/percent_target_test.exs`.

## Batch 1: Literal

**Status:** done

**Scope:** A percent literal parses, validates, and evaluates. Excludes arithmetic, functions, and host options.

### Task 1.1: Struct, inspect, and labels

**Status:** done — `85b9ced`

- Files: Create `lib/elex/percent.ex`; Modify `lib/elex/labels.ex`; Test `test/elex/percent_test.exs`, `test/elex/labels_test.exs`
- TDD: yes
- UI flow: N/A
- Verify: `mix test test/elex/percent_test.exs test/elex/labels_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - `%Elex.Percent{value: Decimal.new("50")}` inspects as `#Elex.Percent<50%>`
  - `%Elex.Percent{value: Decimal.new("-10")}` inspects as `#Elex.Percent<-10%>`
  - `Elex.Labels.label(:percent)` is `"percent"`
  - `Elex.Labels.got(:percent)` is `"got percent"`
- Out of scope: parser, validate, evaluate

### Task 1.2: Parse and evaluate literals

**Status:** done — `980da19`

- Files: Modify `lib/elex/parser.ex`, `lib/elex/validator.ex`, `lib/elex/evaluator.ex`, `lib/elex.ex`; Test `test/elex/expression/percent_literal_test.exs`
- TDD: yes
- UI flow: Flow 1
- Verify: `mix test test/elex/expression/percent_literal_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 1 steps 1–12, including a length catalog on `validate("50%")` still returning `:percent`
  - Flow 1 error paths
  - `evaluate` typespec and validate docs list `%Elex.Percent{}` and `:percent`
- Out of scope: operators other than the unary minus in `-(50%)`

## Batch 2: Arithmetic, comparisons, and literal zero

**Status:** done

**Scope:** Scaling, percent `+` `-` `*`, the division ban, comparisons, and literal zero in comparisons and in `min`, `max`, `clamp`, `between`, `if`, and `coalesce`. Excludes `pow`, `sqrt`, `abs`, `round`, `floor`, `ceil`, `mod`, variables, Ash, invert, and autocomplete.

### Task 2.1: Scale a number or a quantity

**Status:** done — `966b6b3`

- Files: Modify `lib/elex/validator.ex`, `lib/elex/evaluator.ex`; Test `test/elex/expression/percent_scale_test.exs`
- TDD: yes
- UI flow: Flow 2
- Verify: `mix test test/elex/expression/percent_scale_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 2 steps 1–8
- Out of scope: percent `+` `-`, percent `*` percent, division

### Task 2.2: Add, subtract, and multiply percents

**Status:** done — `952a476`

- Files: Modify `lib/elex/validator.ex`, `lib/elex/evaluator.ex`; Test `test/elex/expression/percent_arithmetic_test.exs`
- TDD: yes
- UI flow: Flow 3
- Verify: `mix test test/elex/expression/percent_arithmetic_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 3 steps 1–7
  - Flow 3 error paths, including `10% + 0`
- Out of scope: division, comparisons

### Task 2.3: Reject division

**Status:** done — `1f0333f`

- Files: Modify `lib/elex/validator.ex`; Test `test/elex/expression/percent_arithmetic_test.exs`
- TDD: yes
- UI flow: Flow 4
- Verify: `mix test test/elex/expression/percent_arithmetic_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 4 division error paths all return `cannot divide with a percent`
- Out of scope: `mod` (Task 3.3)

### Task 2.4: Comparisons and literal zero

**Status:** done — `d910ced`

- Files: Modify `lib/elex/validator.ex`, `lib/elex/evaluator.ex`; Test `test/elex/expression/percent_compare_test.exs`
- TDD: yes
- UI flow: Flow 5
- Verify: `mix test test/elex/expression/percent_compare_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 5 steps 1–7
  - Flow 5 error paths
- Out of scope: `min`, `if`, `+`

### Task 2.5: `min`, `max`, `clamp`, `between`

**Status:** done — `aeffeeb`

- Files: Modify `lib/elex/validator.ex`, `lib/elex/evaluator.ex`; Test `test/elex/expression/percent_minmax_test.exs`
- TDD: yes
- UI flow: Flow 6
- Verify: `mix test test/elex/expression/percent_minmax_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 6 steps 1–11
  - Flow 6 error paths
- Out of scope: `if` and `coalesce` (Task 2.6); evaluating `abs` / `round` / `floor` / `ceil` (Task 3.1)

### Task 2.6: `if` and `coalesce`

**Status:** done — `f1bc2b3`

- Files: Modify `lib/elex/validator.ex`, `lib/elex/functions/if.ex`, `lib/elex/functions/coalesce.ex`, `lib/elex/evaluator.ex`; Test `test/elex/expression/percent_if_test.exs`
- TDD: yes
- UI flow: Flow 7
- Verify: `mix test test/elex/expression/percent_if_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 7 steps 1–9
  - Flow 7 error paths
- Out of scope: `min` / `clamp`; `+` / `-`

## Batch 3: Functions and host API

**Status:** done

**Scope:** Pointwise math, `pow`, `sqrt`, remainder rejection, variables, Ash, invert, autocomplete, `unit:` / `category:`, and docs. Excludes new operator rules.

### Task 3.1: `abs`, `round`, `floor`, `ceil`

**Status:** done — `795458c`

- Files: Modify `lib/elex/functions/abs.ex`, `lib/elex/functions/round.ex`, `lib/elex/functions/floor.ex`, `lib/elex/functions/ceil.ex`, `lib/elex/evaluator.ex`; Test `test/elex/expression/percent_round_test.exs`
- TDD: yes
- UI flow: Flow 8
- Verify: `mix test test/elex/expression/percent_round_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 8 steps 1–9
  - Flow 8 error path for `concat`
- Out of scope: `pow` and `sqrt`

### Task 3.2: `pow` and `sqrt`

**Status:** done — `326b781`

- Files: Modify `lib/elex/functions/pow.ex`, `lib/elex/functions/sqrt.ex`, `lib/elex/evaluator.ex`; Test `test/elex/expression/percent_pow_test.exs`
- TDD: yes
- UI flow: Flow 9
- Verify: `mix test test/elex/expression/percent_pow_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 9 steps 1–12
  - Flow 9 error paths
- Out of scope: `round`

### Task 3.3: Reject `mod`

**Status:** done — `0151c13`

- Files: Modify `lib/elex/labels.ex` if `got/1` is not already done; Test `test/elex/expression/percent_remainder_test.exs`
- TDD: yes
- UI flow: Flow 4
- Verify: `mix test test/elex/expression/percent_remainder_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 4 `mod` error path
- Out of scope: division (Task 2.3)

### Task 3.4: Percent variables

**Status:** done — `2d14d00`

- Files: Modify `lib/elex.ex`, `lib/elex/variable.ex`; Test `test/elex/expression/percent_variable_test.exs`
- TDD: yes
- UI flow: Flow 10
- Verify: `mix test test/elex/expression/percent_variable_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 10 steps 1–5
  - Flow 10 error paths
- Out of scope: Ash

### Task 3.5: Ash `expected_type: :percent`

**Status:** done — `8329358`

- Files: Modify `lib/elex/ash_validation.ex`; Test `test/elex/ash_validation_test.exs`
- TDD: yes
- UI flow: Flow 12
- Verify: `mix test test/elex/ash_validation_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 12 steps 1–2
  - Flow 12 Ash error paths (`must return percent, but returns decimal` and `must return decimal, but returns percent`)
- Out of scope: `unit:` and `category:` (Task 3.8)

### Task 3.6: Invert refuses a percent

**Status:** done — `07f3f19`

- Files: Modify `lib/elex/inverter.ex`; Test `test/elex/expression/inverter_test.exs`
- TDD: yes
- UI flow: Flow 11
- Verify: `mix test test/elex/expression/inverter_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 11 steps 3–4
- Out of scope: autocomplete

### Task 3.7: Autocomplete

**Status:** done — `462a0d2`

- Files: Modify `lib/elex/autocomplete.ex`; Test `test/elex/autocomplete_test.exs`
- TDD: yes
- UI flow: Flow 11
- Verify: `mix test test/elex/autocomplete_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 11 steps 1–2
- Out of scope: suggesting `%`; invert (Task 3.6)

### Task 3.8: `unit:` and `category:`

**Status:** done — `c1f654c`

- Files: Modify `lib/elex/evaluator.ex`, `lib/elex.ex`; Test `test/elex/expression/percent_target_test.exs`
- TDD: yes
- UI flow: Flow 12
- Verify: `mix test test/elex/expression/percent_target_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - `validate("50%", ctx, category: :length)` → `length was expected, got percent`
  - `evaluate("50%", ctx, unit: "cm")` when `cm` is registered → `cannot convert percent to a unit`
- Out of scope: Ash (Task 3.5)

### Task 3.9: Guides and changelog

**Status:** done — `9bc900e`

- Files: Modify `guides/expression-language.md`, `guides/functions.md`, `README.md`, `CHANGELOG.md`, `lib/elex/function.ex`
- TDD: no
- UI flow: N/A
- Verify: `mix test test/elex/expression/percent_literal_test.exs test/elex/expression/percent_arithmetic_test.exs test/elex/expression/percent_compare_test.exs`
- Domain skills: none
- Acceptance:
  - Expression-language guide documents the `%` suffix, percent `+` `-` `*`, the division ban, and literal `0`
  - Functions guide states that `pow` / `abs` / `round` / `min` / `if` accept a percent, and that `sqrt` / `mod` do not
  - `function.ex` documents that literal `0` next to a percent follows the quantity rule for `same_numeric_type/2`
  - README shows `100 * 50%` evaluating to `50` and does not call `%` a remainder operator
  - Unreleased changelog records the percent suffix under Added
- Out of scope: code behaviour (Tasks 1.1–3.8)
