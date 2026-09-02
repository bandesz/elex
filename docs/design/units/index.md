# Units (opt-in)

Generic unit support for Elex expressions. **Elex does not ship a unit system.** Callers (and tests) register categories, units, conversions, and derived formulas on the context. Units are off until a catalog is attached.

## Status

Complete. Unique dimensions, no evaluate snap to hub, `%Elex.Unit{}`, atomic names with digits, `convert/2`, inspect with `^`. Non-additive categories (`additive: false`): no `+ − * /`, no mixed C/F in `:point` functions; `add_unit` / `remove_unit`; function `signature` `units:`.

Validate returns a **category formula** (base categories → exponents). Evaluate returns a **unit monomial**. Optional `category:` / `unit:`. Unit formulas use `|` (not `/`). See [2026-08-24 plan](../../plans/2026-08-24-units-validate-evaluate-design.md).

A derived category (`formula:` over base names, e.g. `length * length`) must have a unit whose monomial is the product of the **base hubs** (`m * m` when `:length` defaults to `m`). `put_units` rejects a derived category that only has aliases (`m2`, `ha`). `Catalog.kind/2` is `{:ok, :base} | {:ok, :derived} | :error`. Formula `unit:` / `convert` uses the same identity walk as named targets.

`add_unit` takes `aliases:` (input-only names). Canonical name is the stored unit (`"m^2"`, `"cm^2"`); aliases (`m2`, `sqm`, `cm2`) parse but the result monomial is the canonical formula (`%{"m" => 2}`), never `%{"m2" => 1}`. Expression literals accept `5 m^2` / `5m^2` (positive integer exponent).

`add_unit/3` omits `"value"`. Derived `add_category` takes optional `identity:` (base-hub formula) so a named hub such as `"N"` can name `"kg * m | s^2"`. A matching identity unit must still be registered.

Unbraced pipe suffixes (`3 m|s`, `3 m | s^2`) and braced full formulas (`1 {kg * m | s}`). Inspect does not insert braces. Unbraced `1 kg * m | s` stays invalid (`*` is expression multiply).

## Start here

| Doc | What it contains |
|---|---|
| [user-flows.md](user-flows.md) | Canonical behaviour — numbered caller journeys |
| [architecture.md](architecture.md) | Catalog, Unit struct, parser, dimension vectors, Quantity |
| [data-flow.md](data-flow.md) | Register → parse → validate → evaluate |
| [error-handling.md](error-handling.md) | Registration, parse, validate, evaluate errors |
| [testing-strategy.md](testing-strategy.md) | ExUnit mapping from flows to test files |

## Problem

Today every number is a dimensionless `Decimal`. Callers (manufacturing expressions) need dimensional checking, left-to-right conversion within a category, derived quantities (`m * m`, `m / s`), and explicit conversion (`m/s` → `km/h`) from **component** conversions only. Conversion and naming must not be guessed (energy vs torque, auto-`N`, affine-as-scale).

## Constraints

- Opt-in: `Elex.Context.units` is `nil` by default; same `validate` / `evaluate` APIs
- No built-in SI, imperial, or temperature catalog
- Unit suffixes on **numeric literals only** (`10mm`, `10 mm`, `3 m|s`, `1 {kg * m | s}`); never on variable names or parenthesized expressions
- Conversions are Elex expressions in `value`, inverted with `Elex.Inverter` (scale and affine)
- Functions: preserve-and-restrict (`sqrt` / `pow` / strings reject units)
- Manufacturing: operational quantities; unique dimensions; torque vs energy as separate **base** categories if both are needed

## Decisions

1. **Architecture:** catalog on the context; dimension vectors in validator/evaluator (not a parallel pipeline, not Quantity-in-AST for every number).
2. **Validate type:** category **formula** (base categories → exponents, e.g. `length | time`) or `:decimal` / `:boolean` / `:string`. Never a derived atom (`:speed`). Optional `category: :speed` checks compatibility with that category’s formula; on success still returns the inferred formula. Unregistered products (`1m * 1m` → `length^2`) are valid when `category:` is omitted.
3. **Evaluate value:** `Decimal` if dimensionless; `%Elex.Quantity{value, unit: %Elex.Unit{}}` if unitful. `%Elex.Unit{}` is **only** a unit monomial. Optional `unit:` converts. Evaluate does **not** snap to the category hub. Incompatible `unit:` errors from the **target**’s category (`expression should return a valid length result`).
4. **Same-category `A op B` (additive categories only):** convert B into A’s unit (left-associative), including `1m + 1ft`. Non-additive categories reject binary `+ − * /`.
5. **Conversion hub:** every category (base and derived) has `default:` — the hub for converting **between registered units of that category**, not the evaluate result. `1mm` stays mm; `1m * 2m` stays `m * m`.
6. **Component conversion:** `m/s` → `km/s` only needs `m↔km`; do not register `km/s`. Linear only; non-additive symbols in `*` `/` or compound `unit:` / `convert` targets error.
7. **Identity (required on derived):** the base-hub product (length hub `m` → area `%{"m" => 2}`; mass/length/time hubs `kg`, `m`, `s` → force `%{"kg" => 1, "m" => 1, "s" => -2}`). Satisfied by: (a) `default:` name parses to that monomial (`"m^2"`), or (c) a registered unit whose name parses to it (`"kg * m | s^2"`). Optional `identity:` on `add_category` names that formula and must parse to the same monomial; it does **not** substitute for a registered unit. Hub `default:` is a canonical unit name, not an alias. Named convert and formula `unit:` / `convert` walk this identity. Evaluate does not auto-rename `1kg * 1m / (1s * 1s)` to `N`.
8. **Area has no automatic name; power aliases do not appear in results:** `1m * 2m` stays monomial `%{"m" => 2}` (inspect `m^2`). Register the identity as `"m^2"` (or `"m * m"`) with `aliases: ["m2", "sqm"]`. Input `5 m2` / `5 sqm` / `5 m^2` all evaluate to `%{"m" => 2}`; inspect never prints `m2` or `sqm`. A unit registered as canonical `"m2"` (no aliases) still stores `%{"m2" => 1}` — omit that if you do not want the short name in output. `1m2 / 1m` is `1 m`. `1N / 1kg` still expands the named hub during `*` `/` to `m | s^2`. Root need not be a registered category.
9. **Unique dimensions:** registering a second category with the same dim vector is an error.
10. **`%Elex.Unit{}`:** canonical **unit** monomial only. `Unit.same?/2` / `Unit.convertible?/3` (catalog, same dim). `Unit.compatible?/3` maps a unit monomial to a category formula. Inspect uses `|` and `^` (`m^2`, `m | s^2`).
11. **Non-additive categories:** `add_category(..., additive: false)` (default `true`). Offset conversions (`to_default(0) ≠ 0`) are allowed only on non-additive categories. No binary `+ − * /` (including `1C + 2C`, `2 * 1C`, `1C / 1s`). Unary minus is a point op (`-5C`). Same-unit point functions (`min`, `max`, `if`, `between`, `clamp`, `ceil`, `floor`, `round`, `abs`, compare) are allowed; mixing `1C` and `2F` is not. `convert(32F, "C")` is the explicit scale change. Arithmetic on magnitudes is `add_unit(remove_unit(2C) + remove_unit(3C), "C")`. Gauge pressure is the same pattern. Heating rates stay a **linear** category (`Cps`), not `C | s`. Forgetting `additive: false` on a C-only catalog leaves `2 * 1C` legal.
12. **Formula language:** `|` is the only fraction bar (`m | s^2`). Multiply with `*`, middot, or whitespace. At most one `|`. No `/` or parentheses in formulas. Integer `^` (`m | s^2`). Trailing digits are **not** exponents (`s2` is the symbol `s2`). `^` is not part of the expression language (`5m ^ 2` hints to write `5m^2`). Expression arithmetic still uses `/` (`10m / 1s`). A formula **unit name** that places the same **category** in both the numerator and the denominator is a registration error (`N * s | s`, `N * s | hour`). That check walks `|` and negative exponents **before** monomial cancellation. `"m * m"` is valid.
13. **Literal suffixes (names, powers, pipes, braces):** a numeric literal takes (a) a registered name or alias, (b) `symbol^positive-integer`, (c) an **unbraced pipe** of one atom per side (`3 m|s`, `3m|s`, `3 m | s`, `3 m|s^2`, `3 m^2|s^2` — optional space after the number and around `|`; no spaces around `^`), or (d) a **braced formula** (`1 {kg * m | s}`, `1{kg * m | s}`) using the same formula language as `unit:` (`*`, middot, whitespace, `|`, `^`). `"10m / s"` is metres divided by variable `s`. `5m ^ 2` hints to write `5m^2`. `1 kg * m | s` is `(1 kg) * m` then unexpected `|` (hint: compound units belong in braces) — `*` is never formula multiply outside braces. `3 m | s * s` and `3 m | s * h` (when `h` is a registered unit) are parse errors (unbraced pipes cannot continue with `* <unit>`); write `3 m|s^2` or `3 {m | s * s}`. `3 m | s * 2` is `(3 m|s)*2`. Arithmetic `10m / 1s` and `1kg * 1m|s` stay valid. If `"m^2"` is not a registered unit name but `m` is, `5 m^2` is the power monomial `%{"m" => 2}`. Braces are expression-suffix syntax only — not in catalog names, `unit:`, `convert/2`, or `add_unit/2`. `add_unit` stays symbol-or-alias. `1 {m}` and `1 {m | s}` are allowed (redundant). Suffixes still attach only to numeric literals (`(1+2) {m}` is invalid).
14. **`convert/2`:** in-expression form of `evaluate(..., unit:)`. `convert(value, "mm")` — first arg unitful, second a string (symbol or formula). Result stays in that category. Root `unit:` remains.
15. **`add_unit` / `remove_unit`:** work on every quantity. `remove_unit(2C)` → Decimal `2`; `add_unit(5, "C")` → `5 C`. Second arg is a registered **canonical name or alias** (`"m2"`, `"m^2"`), not an unregistered compound (`"m / s"` is invalid). Result monomial is the canonical unit’s formula. Already-unitful `add_unit` errors (`add_unit cannot wrap a quantity that already has a unit`) and dimensionless `remove_unit` error.
16. **Function `units:`:** `signature/0` includes `units: :point | :additive | :none | :convert | :wrap | :unwrap` (default **`:additive`**). `:point` — same category; if non-additive, `Unit.same?` (no silent F→C). Linear `:point` still converts `min(1m, 1km)`. `if` and `coalesce` are `:point`. `:additive` — reject non-additive args; may convert linear. `:none` — reject all quantities (`pi` is `:none`). `:convert` / `:wrap` / `:unwrap` are `convert`, `add_unit`, and `remove_unit`. Evaluator aligns later args only for `:additive` functions (and linear `:point` same-category convert into first/then unit).
17. **Kind query:** `Catalog.kind/2` → `{:ok, :base} | {:ok, :derived} | :error`. Single `add_category/3`; `formula:` is what makes a category derived.
18. **Identity walk:** evaluate convert/compare uses the catalog **base-hub identity** required by `put_units` (`%{"m" => 2}`, `%{"kg" => 1, "m" => 1, "s" => -2}`), never the first compound name in the category (`km * km` next to `m * m` is not the identity).
19. **`aliases:` on `add_unit`:** extra input spellings of one canonical unit. Canonical = what inspect prints. `m2` / `sqm` are aliases of `"m^2"`. `N` is canonical (you want `#Elex.Quantity<1 N>`), not an alias of `kg * m | s^2`. Aliases are symbol-pattern names, unique catalog-wide, not valid as `default:`.
20. **`add_unit/3` and `identity:`:** `Catalog.add_unit(catalog, :length, "m")` means `to_default` `"value"`. `add_unit/4` with an explicit conversion still works. Derived `add_category` may take `identity: "kg * m | s^2"` to name the base-hub product; a matching unit is still required at `put_units`. Base categories reject `identity:`. `identity:` must parse to the base-hub product.
21. **Inspect is not input:** `#Elex.Quantity<1 m | s>` and `#Elex.Quantity<1 kg * m | s>` never insert `{}`. Copying inspect of a multi-factor unit into an expression requires braces (`1 {kg * m | s}`) or factor arithmetic (`1kg * 1m|s`).

## Assumptions

- Identity monomial is each base category’s `default:` symbol to the formula exponent (`"m^2"` equals `"m * m"`).
- Missing identity is a `put_units` error; a catalog that attached cannot later fail convert for lack of identity.
- Exponents in literal suffixes are **positive integers** only (`m^2`, `mm^3`; not `s^-2` as a suffix).
- `5m^2` and `5 m^2` are valid; `5m ^ 2` is not.
- `ha`, `N`, and `L` stay named unless registered as aliases of a formula unit.
- `add_unit/4` takes an explicit conversion; `aliases:` is an optional keyword list (default `[]`).
- Unregistered `m2` is `unknown unit 'm2'` (no trailing-digit expansion). `m2` works only as an alias or a canonical name.
- `add_unit(catalog, category, name)` and `add_unit(catalog, category, name, aliases: …)` omit conversion (`"value"`). `add_unit(catalog, category, name, to_default)` and `/5` with opts stay.
- Registering `"kg * m | s^2"` as a unit still satisfies identity (path c).
- `identity:` names the identity formula; a matching unit is still required. Newton registers `"kg * m | s^2"` with `"value"`; hectare registers `"m^2"` with `"value / 10000"`.
- No `add_default_unit/3`. `default:` on the category already names the hub.
- Unbraced pipe: at most one `|`; each side is a single symbol or `symbol^n` (positive `n` on the suffix). No `*` or juxtaposition in an unbraced suffix.
- Inside braces, `Formula.parse` is the grammar (`s^-1`, `1 | s`, `kg m | s`, `kg * m | s^2` all legal when symbols exist).
- Parser emits `{:unit, decimal, suffix_string}`; validate/evaluate walk formula strings via `Formula.parse` / `Unit.new!` (same path as `5 m^2`).
- `1 kg * m | s` is a parse error; the message hints at braces (`1 {kg * m | s}`).
- `add_unit(1, "kg * m | s")` is rejected (symbol or alias only).
- No catalog: `1 {m | s}` is `unexpected '{'` (same class as `1cm` → `unexpected 'cm'`).

## Non-goals

- Unbraced `1 kg * m | s` as a formula (would steal expression `*`)
- Juxtaposition continuation (`1 kg m | s` as one suffix)
- Braces in formula strings (`unit: "{kg * m | s}"`, catalog names, `convert`)
- Changing Quantity/Unit inspect to insert `{}`
- `add_unit/2` accepting formulas
- Suffixes on parenthesized expressions (`(1+2) {m}`)
- Unbraced negative exponents (`1s^-2`); those belong inside braces

## Public surface

Expression unit-suffix grammar on numeric literals (parser). `evaluate` / `validate` / `Parser.parse` are additive.

- Valid: `evaluate("3 m|s", ctx)` → `#Elex.Quantity<3 m | s>` when `m` and `s` are registered
- Valid: `evaluate("1 {kg * m | s}", ctx)` → `#Elex.Quantity<1 kg * m | s>`
- Invalid: `evaluate("1 kg * m | s", ctx)` → `unexpected '|'; compound units belong in braces, for example 1 {kg * m | s}`

No extra Elixir functions for suffixes. Catalog / `unit:` / `convert/2` strings stay unbraced.

User flows in `user-flows.md` are canonical.
