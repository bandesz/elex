# Not-derivable units

A caller can mark a unit `derivable: false` so a derived category keeps its own name inside a formula. Litre then stays volume when written against length, and `L | 100 km` can be registered on `volume | length` while `m^3` still reduces to length.

Follow-on to [denominator scale](../denominator-scale/index.md) and [inverse conversion](../inverse-conversion/index.md). User flows in [user-flows.md](user-flows.md) are canonical.

## Implementation status

**Status:** complete
**Review fixes:** `bc335d6`

## Problem and constraints

`L | 100 km` already registers when volume is a base category. It fails when volume is derived from length. Elex expands every unit of a derived category to that category's reduced dimension before the repeat check, before the dimension check, and again while multiplying or dividing. Litre becomes length³. `L | 100 km` then has length on both sides, so it repeats `:length`. Cancelling those exponents leaves length², which is area, so the formula also fails the fuel dimension. The same expansion turns `1 L / 1 m` into square metres as soon as the quantity is divided.

`m^3 | m` must still repeat length and reduce to area. `1 ha / 1 m` must still be length. An opaque name is not a reason to skip expansion.

**Constraints:**

- Opt-in catalogs. Elex still ships no unit system. Fluid ounce and imperial volume units are not added; a caller passes `derivable: false` when they register one.
- The mark does not change a conversion string. `convert(1 L, "m^3")` uses the stored factor.
- Same-category addition and division stay category-membership operations through the category hub. They must not treat nominal `volume` and reduced `length^3` as different dimensions.
- One denominator coefficient, already shipped in 0.4.1. The fuel hub is per 1. `default: "L | 100 km"` stays rejected.
- Spacing is not significant. `L|100km` is the same unit as `L | 100 km`.
- `kWh | 100 km` needs no mark. Energy is a base category, so kilowatt-hour is never expanded into length.

## Decisions

1. **Per-unit mark.** `add_unit` takes `derivable: false`. Omitted and `derivable: true` store nothing and mean derivable. The flag lives on the catalog unit entry. Aliases use the canonical entry. It is not a field of `%Elex.Unit{}`.
2. **Two contributions.** In a formula or a cross-category product, a not-derivable symbol contributes its category atom (`volume`). A derivable symbol contributes the category's stored `:dim` (`length^3` for volume, `length^2` for area). Base categories are unchanged.
3. **Category formulas may name a derived category.** `volume | length` stores `%{volume: 1, length: -1}`. `reject_duplicate_dim` uses that vector, so fuel does not collide with area's `%{length: 2}`. All-base formulas still store the reduced vector (`length^3`, `length | time^2`).
4. **Identity.** When every formula component is a base category, the base-hub identity is unchanged (`m^2`, `kg * m | s^2`). When a component is derived, `identity:` is rejected. `put_units` succeeds when a registered per-1 unit has the category's nominal dimension. `L | km` qualifies because `L` is volume and `km` is length. `m^3 | m` is not required and cannot be registered on `:fuel`.
5. **Scale check.** Compare the unit's nominal monomial with the hub monomial. Do not replace a not-derivable symbol with the category default first. Same symbols mean the expected conversion at 1 is `1 / per` (`"value / 100"` for `L | 100 km`). Different symbols with the same nominal dimension use `component_factor(unit) / component_factor(hub) / per`, so `mL | 100 km` stays `"value / 100000"`.
6. **Same-category arithmetic uses membership.** `1 L` and `1 m^3` are both `:volume`. Addition converts through `m^3`. Division cancels to a number. `Unit.convertible?/3` is true for those two units. A pure nominal power `%{volume => n}` is the same dimension as volume's stored `:dim` scaled by `n`. A mixed vector such as `%{volume: 1, length: -1}` is not rewritten to `length^2`.
7. **Evaluation uses the same split.** `expand_derived_aliases` and the validator's derived expansion do not replace a not-derivable symbol with the category identity. Derivable symbols still expand.

Rejected alternatives:

- A category-wide flag would also stop `m^3` and `cm^3` from reducing.
- Treating every opaque name as not derivable would stop hectare from expanding.

## Assumptions

- `derivable:` other than `true` or `false` → `derivable: must be a boolean`.
- `identity:` when the formula names a derived category → `identity: is not allowed when :fuel formula names a derived category`.
- `validate("1 L")` stays `#Elex.Dimension<length^3>`, volume's stored dimension. The mark is visible once litre is written against another category.
- `8 {L | 100 km} * 100 km` validates as `#Elex.Dimension<length^3>` because only `volume` remains, and that pure power is volume's stored dimension. The quantity inspects as `8 L`.
- `1 / 8 {L | 100 km}` validates as `#Elex.Dimension<length | volume>`.
- `category_for_dim` stays an exact match on the stored `:dim`. `%{volume: 1}` is not a second stored key for `:volume`.
- Addition of a pure `volume` dimension and a `length^3` quantity succeeds because both are `:volume`, and the sum's dimension is `length^3`.
- Existing denominator-scale tests keep volume as a base category and do not pass the flag.
- `speed | time` is now a legal category formula. Its dimension is `%{speed: 1, time: -1}`, which is not acceleration's `%{length: 1, time: -2}`. The error `formula may only use base categories` is removed.
- `1 L + 1 m^3` converts into the left unit: `1001 L`. `1 m^3 + 1 L` is `1.001 m^3`. `1 L / 1 m^3` is the decimal `0.001`.
- `1 km = 1000 m`, `1 L = 0.001 m^3`, `1 mL = 0.000001 m^3`, `1 gallon = 0.003785411784 m^3`, `1 mile = 1609.344 m`.
- The mile-per-gallon conversion string stays `"3.785411784 / 1.609344 / value"` because that string maps to the `L | km` default, not to `m^3`.

## Non-goals

- A built-in list of litre, millilitre, gallon, fluid ounce, or imperial volume units
- Changing `m^3`, `cm^3`, or hectare to `derivable: false`
- A denominator coefficient on the category default
- Requiring a registered `m^3 | m`
- Rewriting `volume | length` to `length^2` anywhere in registration, validate, or evaluation
- Changing same-category conversion factors

## Public surface

`Catalog.add_unit/4` and `add_unit/5` gain `derivable:`. Compatibility: **additive**. Omitted means derivable.

`Catalog.add_category/3` accepts a `formula:` that names a derived category and stores the nominal dimension. Compatibility: **additive**. Callers who passed a derived component previously got `formula may only use base categories; :speed is derived`. That call now registers the category.

`Catalog.dimension/2` for `:fuel` returns `%Elex.Dimension{monomial: %{volume: 1, length: -1}}`. `%Elex.Dimension{}` may name a derived category atom. Existing all-base dimensions are unchanged. Compatibility: **additive**.

`Unit.convertible?/3` stays true for two units in the same category. `Unit.compatible?/3` stays true for a not-derivable litre and `:volume`, and is true for `L | m` and `:fuel`.

Who can call: any caller with a catalog. No actor or tenant.

- Valid: `Catalog.add_unit(catalog, :volume, "L", "value / 1000", derivable: false)` → `{:ok, catalog}`
- Valid: `Catalog.add_category(catalog, :fuel, formula: "volume | length", default: "L | km")` → `{:ok, catalog}` and dimension `volume | length`
- Invalid: `Catalog.add_unit(catalog, :fuel, "m^3 | m", "value")` → `{:error, "formula 'm^3 | m' repeats category :length in the numerator and denominator"}`
- Invalid: `Catalog.add_unit(catalog, :volume, "L", "value / 1000", derivable: "no")` → `{:error, "derivable: must be a boolean"}`

## Architecture

The catalog unit map gains optional `derivable: false`. `lookup_symbol_dim` reads it. Not-derivable symbols contribute `%{category => exponent}`. Derivable symbols contribute `scale(category.dim, exponent)`. The repeat check, formula dimension check, `Catalog.unit_dim/2`, and cross-category `*` `/` in the validator all use that contribution.

`category_formula_dim` no longer stops on a derived component and no longer inlines that component's `:dim`. It stores `%{component_category => exponent}`. `identity_monomial` must not pattern-match only the base-category success tuple. For a formula that names a derived category it does not build a base-hub monomial. `fetch_derived_identity` rejects `identity:`. `validate_derived_identity` accepts a registered per-1 unit whose nominal dimension equals the stored vector.

`compare_expanded_component_scale/6` must not skip when litre would expand to `m^3` while the hub is `L | km`. It compares nominal monomials. Equal nominal monomials expect the component-factor ratio divided by `per` (ratio 1, so `1 / per`, when the symbols match).

The validator calls `Catalog.same_category_dim?/3` for `+` and `/` (`add_sub_dim` and `cancelling_division?` in `lib/elex/validator.ex`). The evaluator calls it for `/` only (`divide_quantities` → `same_category_units?` in `lib/elex/evaluator.ex`). Evaluator `+` (`evaluate!({:+, ...})`) converts the right quantity into the left unit with `convert_to/3`. Named units in one category go through the category hub. Other formulas, including `1 L^2 + 1 km^6`, go through base-hub expansion (`convert_via_base_hub/4`). `same_category_dim?/3` is true when `Unit.reduce_nominal_power/2` yields the same vector. A pure `%{volume => n}` matches volume's stored dimension scaled by `n`, so `%{volume: 1}` and `%{length: 3}` are the same dimension and `%{volume: 2}` matches `%{length: 6}`. A mixed vector such as `%{volume: 1, length: -1}` is left intact.

`expand_derived_unit` and `expand_derived_aliases` skip a symbol whose canonical unit has `derivable: false`. `m^3` and `ha` still expand. `1 m * 1 m * 1 m` is still length³. `convert(1 L, "m^3")` goes through `convert_named_or_hub/4` then `convert_named/4`, because both names are registered in `:volume`, and that path does not read `derivable:`. `named_to_base_hub/3` is the base-hub expansion used for compound formulas. That function also ignores the mark. When the category has an identity, it continues through `Catalog.formula_identity/2`.

## Error handling

| Situation | Message |
|---|---|
| `derivable:` is not a boolean | `derivable: must be a boolean` |
| `identity:` and the formula names a derived category | `identity: is not allowed when :fuel formula names a derived category` |
| Not-derivable litre omitted, then `L \| km` on `:fuel` | `formula 'L \| km' repeats category :length in the numerator and denominator` |
| `m^3 \| m` or `cm^3 \| m` on `:fuel` | `formula 'm^3 \| m' repeats category :length in the numerator and denominator` |
| Second category with the same nominal vector | `category :economy has the same dimension as :fuel` |
| Scaled unit whose symbols match the hub but the factor is not `1 / per` | `unit 'L \| 100 km' conversion does not match the scale of its component units` |
| `mL \| 100 km` ignores the millilitre factor | `unit 'mL \| 100 km' conversion does not match the scale of its component units` |
| No per-1 unit has the nominal dimension | `derived category :fuel needs a registered per-1 unit whose dimension is volume \| length` |
| `default:` has a coefficient | `default unit 'L \| 100 km' cannot include a denominator coefficient` |
| Add litre to kilometres | `cannot add volume and length` |

## Testing strategy

Library-only ExUnit and unit TDD (`test-driven-development`). No UI flow tests. Flows live in [user-flows.md](user-flows.md).

| Flow | File | Proves |
|---|---|---|
| 1, 5 (registration) | `test/elex/units/not_derivable_test.exs` | Derived formula, nominal dimension, mark, repeat, scale |
| 2, 3 | `test/elex/units/not_derivable_test.exs` | Inspect, validate, cancel, same-category add and divide |
| 4 | `test/elex/units/not_derivable_test.exs` | Inverse formula against the nominal dimension |
| 5, 6 | `test/elex/units/not_derivable_test.exs` and `test/elex/units/derived_test.exs` | `m^3`, `cm^3`, and hectare still reduce |
| 7 | `test/elex/units/not_derivable_test.exs` | Base energy needs no mark |
| 1 (old rejection) | `test/elex/units/catalog_test.exs` | `speed \| time` registers; the base-category error is gone |

`guides/units.md` shows volume derived from length, `L` with `derivable: false`, and `L | 100 km`. `CHANGELOG.md` Unreleased.

Coverage of the rows above is in those files. Flows 1–7, including the error paths, are in `test/elex/units/not_derivable_test.exs`.

## Batch 1: Nominal dimension

**Status:** done

**Scope:** the mark, derived components in category formulas, and the scale check. Excludes: expression results.

### Task 1.1: `derivable: false` and symbol contribution

**Status:** done — `5f6d483`

- Files: Modify `lib/elex/units/catalog.ex`; Create `test/elex/units/not_derivable_test.exs`
- TDD: yes
- UI flow: Flow 1's derivable-litre repeat, and `m^3 | m` / `cm^3 | m`, asserted on `:volume`. `:fuel` does not exist until Task 1.2.
- Verify: `mix test test/elex/units/not_derivable_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - `add_unit(..., derivable: false)` stores `%{derivable: false}` on that unit entry and not on `m^3`
  - `derivable: true` and an omitted flag store no `:derivable` key
  - `derivable: "no"` → `derivable: must be a boolean`
  - An alias of not-derivable `L` uses the canonical entry: `Catalog.unit_dim(catalog, %{"alias" => 1})` is `{:ok, %{volume: 1}}`
  - With the mark, `Catalog.unit_dim(catalog, %{"L" => 1, "km" => -1})` is `{:ok, %{volume: 1, length: -1}}`. Adding `"L | km"` to `:volume` does not repeat `:length`; the error is `formula 'L | km' does not match the category dimension`
  - Without the mark, adding `"L | km"` → `formula 'L | km' repeats category :length in the numerator and denominator`
  - `"m^3 | m"` and `"cm^3 | m"` return that repeat error for `:length`
- Out of scope: `add_category` of `:fuel`, registering `"L | km"` on `:fuel`, scale factors, evaluate

### Task 1.2: Derived components and the nominal identity

**Status:** done — `b0d2478`

- Files: Modify `lib/elex/units/catalog.ex`, `lib/elex/dimension.ex`; Modify `test/elex/units/catalog_test.exs`; Test `test/elex/units/not_derivable_test.exs`
- TDD: yes
- UI flow: Flow 1 steps 1 and 4; Flow 1 error paths for `default:`, `identity:`, and a duplicate dimension; `"L | km"` on `:fuel` with and without the mark; Flow 5 step 5 and the `cm^3 | m` error on that catalog
- Verify: `mix test test/elex/units/not_derivable_test.exs test/elex/units/catalog_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 1 steps 1 and 4
  - `Catalog.dimension(catalog, :fuel)` is `#Elex.Dimension<volume | length>`
  - With `L` marked `derivable: false`, `Catalog.add_unit(catalog, :fuel, "L | km", "value")` → `{:ok, catalog}`
  - Without the mark, `"L | km"` on `:fuel` → `formula 'L | km' repeats category :length in the numerator and denominator`
  - On that catalog, `"m^3 | m"` and `"cm^3 | m"` return that repeat error for `:length`
  - `identity: "m^3 | m"` → `identity: is not allowed when :fuel formula names a derived category`
  - `put_units` does not ask for `m^3 | m`
  - A second `volume | length` category → `category :economy has the same dimension as :fuel`
  - `:area` still requires a registered `m * m` or `m^2`, and `:force` still requires `kg * m | s^2`
  - `formula: "speed | time"` returns `{:ok, catalog}` and dimension `#Elex.Dimension<speed | time>`
- Out of scope: denominator coefficient scale, evaluate

### Task 1.3: Scale check against the nominal hub

**Status:** done — `0b34fd4`

- Files: Modify `lib/elex/units/catalog.ex`; Test `test/elex/units/not_derivable_test.exs`
- TDD: yes
- UI flow: Flow 1 steps 2 and 3; Flow 1 scale error paths; Flow 7 steps 1 and 2 and its error path
- Verify: `mix test test/elex/units/not_derivable_test.exs test/elex/units/denominator_scale_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - `"L | 100 km"` with `"value / 100"` → `{:ok, catalog}`
  - `"L | 100 km"` with `"value"` → `unit 'L | 100 km' conversion does not match the scale of its component units`
  - `"mL | 100 km"` with `"value / 100"` returns that scale error, and `"value / 100000"` is `{:ok, catalog}`
  - `"L|100km"` after `"L | 100 km"` → `unit 'L|100km' has the same scale as 'L | 100 km'`
  - Flow 7 steps 1 and 2, and `"kWh | 100 km"` with `"value"` returns the scale error
  - Existing base-volume `L | 100 km` tests still pass
- Out of scope: evaluate, mile per gallon

## Batch 2: Evaluation

**Status:** done

**Scope:** expansion, validate, and arithmetic. Excludes: guides.

### Task 2.1: Cross-category composition keeps litre

**Status:** done — `92af3eb`

- Files: Modify `lib/elex/validator.ex`, `lib/elex/evaluator.ex`, `lib/elex/unit.ex`; Test `test/elex/units/not_derivable_test.exs`
- TDD: yes
- UI flow: Flow 2; Flow 3 steps 1–4 and 8; Flow 3 error paths
- Verify: `mix test test/elex/units/not_derivable_test.exs test/elex/units/derived_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 2 steps 1–8
  - Flow 3 steps 1, 2, 3, 4, and 8
  - `1 L + 1 km` → `cannot add volume and length`
  - `1 / 0 {L | 100 km}` → `division by zero`
  - `Unit.convertible?/3` is true for `L` and `m^3`
  - `Unit.compatible?/3` is true for `L` and `:volume`, and for `L | m` and `:fuel`
- Out of scope: `1 L + 1 m^3`, mile per gallon, hectare, guides

### Task 2.2: Same-category volume and geometric reductions

**Status:** done — `eee351e`

- Files: Modify `lib/elex/evaluator.ex`, `lib/elex/validator.ex`; Test `test/elex/units/not_derivable_test.exs`
- TDD: yes
- UI flow: Flow 3 steps 5–7 and 9; Flow 4; Flow 5 steps 1–4; Flow 6; Flow 7 step 3
- Verify: `mix test test/elex/units/not_derivable_test.exs test/elex/units/derived_test.exs test/elex/units/inverse_conversion_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 3 steps 5, 6, 7, and 9
  - Flow 4 steps 1–4 and both error paths
  - Flow 5 steps 1–4
  - Flow 6 steps 1 and 2
  - Flow 7 step 3
- Out of scope: guides, changelog

## Batch 3: Docs

**Status:** done

**Scope:** guide and changelog. Excludes: behaviour changes.

### Task 3.1: Guide and changelog

**Status:** done — `140f593`

- Files: Modify `guides/units.md`, `CHANGELOG.md`
- TDD: no
- UI flow: N/A
- Verify: `mix test test/elex/units/not_derivable_test.exs`
- Acceptance:
  - The units guide shows `:volume` derived from `length * length * length` with hub `m^3`, `L` registered with `derivable: false` and `"value / 1000"`, `:fuel` formula `volume | length` with default `L | km`, and `L | 100 km` with `"value / 100"`
  - The guide states that `m^3` omits the flag and that `1 m^3 / 1 m` remains area
  - Unreleased changelog records `derivable: false` and category formulas that name a derived category, compatibility additive
- Out of scope: code behaviour (Batches 1–2)
