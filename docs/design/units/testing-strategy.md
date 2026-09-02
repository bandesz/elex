# Testing strategy

Library-only: **ExUnit** and unit TDD (`test-driven-development`). No UI flow tests. **No catalog in `lib/`** — fixtures in `test/support/elex/units/`.

Domain skills: `test-driven-development`. Ash task also uses existing `test/elex/ash_validation_test.exs` patterns.

## Flow → tests

| Flow | File | Proves |
|---|---|---|
| 1 | `test/elex/units/disabled_test.exs` | No catalog: `1cm` / `width + 2mm` → `unexpected 'mm'`; unitless APIs unchanged |
| 2 | `test/elex/units/catalog_test.exs` | Registration; reserved names; unique dims; bad conversions |
| 3–4, 10 | `test/elex/units/arithmetic_test.exs` | Left-to-right; targets; scale/cancel; mm kept after cancelling time |
| 19 | `test/elex/units/catalog_test.exs`, `test/elex/units/derived_test.exs` | `put_units` requires base-hub identity; `kind/2`; formula `unit:` through identity |
| 5–7 | `test/elex/units/derived_test.exs`, `test/elex/units/formula_test.exs` | Area monomial; unregistered `mm*mm`; acceleration; `m | s^2`; no root registered-category requirement |
| 20 | `test/elex/units/catalog_test.exs`, `test/elex/units/parser_test.exs`, `test/elex/units/derived_test.exs` | `aliases:`; `5 m2` / `5 m^2` → inspect `m^2`; unknown `m2` without alias |
| 21 | `test/elex/units/catalog_test.exs`, `test/elex/units/conversion_hub_test.exs` | `add_unit/3`; force `identity:` plus identity unit; missing identity unit is `put_units` error; `1N` stays `N` |
| 22 | `test/elex/units/parser_test.exs`, `test/elex/units/derived_test.exs` | `3 m\|s` / `3 m \| s^2`; `1 {kg * m \| s}`; inspect has no braces; `1 kg * m \| s` → unexpected `\|` |
| 8 | `test/elex/units/temperature_test.exs` | `additive: false`; F↔C via `convert`/`unit:`; same-unit point ops; mixed C/F and `+` error |
| 9 | `test/elex/units/variables_test.exs` | Strict category/value; Quantity round-trip |
| 11 | `test/elex/units/functions_test.exs` | Preserve-and-restrict; `between`; `min(1m, 1km)` still converts |
| 12 | `test/elex/units/component_conversion_test.exs` | `m \| s` → `km \| s`, `m \| h`, `km \| h`; `Unit.same?` / `compatible?` |
| 13 | `test/elex/units/conversion_hub_test.exs` | No auto-`N`; `unit: "N"`; `g * m \| s^2` with `unit: "N"` |
| 14 | `guides/advanced.md`, `guides/units.md`, `lib/elex/function.ex` | Custom-function `units:` documented |
| 15 | `test/elex/units/convert_test.exs` | `convert/2`; non-additive result still cannot be scaled |
| 16 | `test/elex/units/unit_test.exs`, `quantity_test.exs` | Inspect `m^2`, `m \| s^2`; alias `m2` does not appear in inspect |
| 17 | `test/elex/units/add_unit_test.exs` (or `convert_test.exs`) | `add_unit` / `remove_unit`; formula target rejected |
| 18 | `test/elex/units/functions_test.exs` + custom-function example | Default `:additive`; `double(1C)` errors |

Parser suffix vs identifier: `test/elex/units/parser_test.exs`. Ash: `test/elex/ash_validation_test.exs` with `expected_type: :length` via `category:`. Unit struct: `test/elex/units/quantity_test.exs` (and unit module tests as added). Formula `|`: `test/elex/units/formula_test.exs`. Compatible helper: `test/elex/units/unit_test.exs`.

## Coverage checklist

- [x] Units off unchanged (Flow 1)
- [x] Catalog registration errors (Flow 2)
- [x] Unique dimension rejection (Flow 2)
- [x] Left-to-right add and mixed same-category (Flow 3)
- [x] Simple and compound `unit:` targets (Flows 4, 12)
- [x] Area without auto-naming (Flows 5–6) — monomial kept
- [x] Unregistered root combination succeeds (`1m * 1m` → `length^2`; `1hour * 1hour` → `time^2`)
- [x] `category: :speed` accepts `1cm / 1s`; rejects `1m * 1m`
- [x] Validate returns `%Elex.Dimension{}`
- [x] Evaluate unit is monomial only (`1mm` → `%{"mm" => 1}`)
- [x] `unit: "km | h"`; `unit: "mm"` on speed → valid length result
- [x] Formula `|` / juxtaposition; reject `/`
- [x] `Unit.compatible?` `cm | s` vs `:speed`
- [x] Cancelled product keeps mm (Flow 10)
- [x] Derived identity required at `put_units`; `Catalog.kind/2` (Flow 19)
- [x] Formula `unit:` / `convert` uses identity (`1ha` → `"m^2"`)
- [x] F↔C via convert / `unit:` (Flow 8)
- [x] Non-additive `additive: false`; offset on additive category rejected (Flow 8)
- [x] Same-unit point ops; mixed C/F error; `1C + 2C` error (Flow 8)
- [x] Variable strictness (Flow 9)
- [x] Quantity round-trip (Flow 9)
- [x] Cancel to Decimal (Flow 10)
- [x] Functions preserve-and-restrict (Flow 11)
- [x] `between` same-category (Flow 11)
- [x] Explicit `unit: "N"` not auto hub (Flow 13)
- [x] Ash category `expected_type` via `category:`
- [x] Custom-function unit docs (Flow 14)
- [x] Formula `^` integer exponents (Flow 7)
- [x] `Unit.convertible?/3` same dim via catalog
- [x] Quantity inspect is `%Elex.Unit{}` only
- [x] `rem` / `mod` / `%` reject quantities (Flow 11)
- [x] Atomic digit names; `s2` is not `s^2` (Flows 5, 7)
- [x] Inspect uses `^` (Flow 16)
- [x] Inspect uses `|` (Flow 16)
- [x] Non-additive `*` `/` including hub (Flow 8)
- [x] `convert/2` (Flow 15)
- [x] `add_unit` / `remove_unit` (Flow 17)
- [x] Function `units:` default `:additive` (Flow 18)
- [x] Base category `default:` must be registered (hub)
- [x] `aliases:` on `add_unit`; result monomial is canonical (Flow 20)
- [x] Literal `5 m^2` / `5m^2`; `5m ^ 2` invalid (Flow 20)
- [x] `5 m2` without alias → `unknown unit 'm2'` (Flow 20)
- [x] `add_unit/3` omits `"value"` (Flow 21)
- [x] Derived `identity:` names the formula; a matching unit is required (Flow 21)
- [x] Base category rejects `identity:` (Flow 21)
- [x] Unbraced pipe suffixes `3 m|s` / `3 m | s^2` (Flow 22)
- [x] Braced formula suffixes `1 {kg * m | s}`; inspect has no `{}` (Flow 22)
- [x] `1 kg * m | s` remains unexpected `|` (Flow 22)

## Verify

Named files for a focused run; `mix test` for the full suite.
