# Architecture

## Context

`Elex.Context` gains `units: nil | Elex.Units.Catalog.t()`. Without a catalog, parse/validate/evaluate behaviour matches unitless Elex.

A catalog is **only** what the caller registers. Nothing in `lib/` defines `m`, `N`, `°C`, or SI.

`Context.put_units/2` returns `{:ok, context} | {:error, String.t()}`. `Catalog.add_category/3` and `add_unit/3` (optional conversion and `aliases:`) return `{:ok, catalog} | {:error, String.t()}`; bang variants raise `ArgumentError`. `put_units` runs `Catalog.validate/1`: every `default:` is among that category’s **canonical** unit names (not aliases), and every derived category has a base-hub identity (`default:` name parses to the identity monomial, or a registered unit whose name parses to it). Optional `identity:` names that formula; it does not substitute for a registered unit.

## Catalog

**Base category:** name (atom), conversion-default unit (`default:` — canonical name), `additive:` (default `true`), list of units. Each unit has a canonical name (symbol or formula string), optional `aliases:`, and an Elex conversion **to the conversion-default** in terms of `value` (omitted `to_default` is `"value"`). Inverse via `Elex.Inverter`. Offset conversions (`to_default(0) ≠ 0`) require `additive: false`.

**Derived category:** name, `formula:` over **base** category names, `default:` hub, optional `identity:` (unit-formula string of the base-hub product), optional `additive:` (default `true`), list of units. `identity:` is rejected on base categories. `Catalog.kind(catalog, name)` is `{:ok, :base}` when there is no `formula:`, `{:ok, :derived}` when there is, `:error` if the name is unknown.

At `put_units` / `Catalog.validate`, a derived category must have the **base-hub product** as identity. That is true when (a) `default:` parses to that monomial (`"m^2"`), or (c) a registered unit name parses to it (`"kg * m | s^2"`). Optional `identity:` must parse to the same monomial; it does not satisfy identity by itself. Missing (a) and (c) is `{:error, "derived category :area needs a registered unit matching the base hubs (e.g. \"m * m\")"}`. Newton registers `"N"` and `"kg * m | s^2"` (`"value"`). Hectare registers `"ha"` and `"m^2"` with a scale.

Example: `:force` with `default: "N"`, `identity: "kg * m | s^2"`, units `"N"` and `"kg * m | s^2"`. Example: `:area` with `default: "m^2"`, unit `"m^2"` and `aliases: ["m2", "sqm"]`. Digit-containing **canonical** names (`mps2`) stay atomic. **Aliases** (`m2`, `cm2`) are extra input spellings; evaluate stores the canonical monomial (`m2` → `%{"m" => 2}`). During `*` `/`, named derived hubs (`N`) expand through the identity (`1N / 1kg` → `m | s^2`).

Two categories may not share a dimension vector. Register torque and energy as **base** categories if both are needed (no silent `N·m` ↔ `J`).

Integer `^` in formulas (`m | s^2`, `length | time^2`, `s^-2`). `|` is the only fraction bar; multiply with `*`, middot, or whitespace; at most one `|`; no `/` or parentheses. Exponents must be non-zero integer literals without a leading zero, not units. A formula that cancels to nothing (`m | m`, `m^0`) is invalid. A formula that places the same base category in both the numerator and the denominator after expanding derived units (`ha | m^2`, `N * s^2 | kg * m`) is invalid. Trailing digits in a **canonical or alias symbol** are part of the name (`s2` is not `s^2`; `m2` is an alias if registered). `^` in the expression language is a **power suffix** on a literal (`1m^2`); `1m ^ 2` stays invalid. Unbraced pipe suffixes (`3 m|s`, `3 m | s^2`) and braced formulas (`1 {kg * m | s}`) are unit suffixes on numeric literals. Unbraced `1 kg * m | s` is not a suffix (`*` is expression multiply).

## Parser

When a catalog is present, a numeric literal may be followed by optional whitespace and one of:

1. A **registered name or alias** — letter, then letters, digits, underscore (`mm`, `m2`, `sqm`, `N`).
2. A **power suffix** — registered symbol, `^`, positive integer (`m^2`, `cm^2`, `mm^3`). No spaces around `^`.
3. An **unbraced pipe suffix** — one atom, optional `|`, one atom. An atom is a registered symbol or `symbol^n` (`m|s`, `m | s`, `m|s^2`, `m^2|s^2`). Optional spaces around `|` only. No `*` or juxtaposition.
4. A **braced formula** — `{` … `}` whose interior is `Elex.Units.Formula` (`{kg * m | s}`, `{kg * m | s^2}`, `{s^-1}`). Optional space before `{`. Braces are not part of catalog / `unit:` / `convert` strings.

If the suffix string equals a registered canonical name (`"m^2"`), use that unit. Else parse it as a formula: every symbol must be registered (`5 m^2` with only `m` → `%{"m" => 2}`; `3 m|s` with `m` and `s` → `%{"m" => 1, "s" => -1}`). A formula that cancels to nothing (`m | m`, `m^0`) or repeats a category in numerator and denominator — including after expanding derived units (`m | mm`, `ha | m^2`, `N * s^2 | kg * m`) — is a syntax error. Empty units are not allowed. An unknown pipe atom is `unknown unit 'foo'` (`3 m|foo`), not unexpected `|`. Unclosed `{` is `unclosed '{'`. Case-sensitive. Reserved words cannot be units (rejected at registration). The AST keeps the suffix string as written (`5 m2` → `{:unit, _, "m2"}`); evaluate stores the canonical monomial (`%{"m" => 2}`).

AST: `{:unit, Decimal.t(), String.t()}` for `10mm`, `10m2`, `10m^2`, `3 m|s` (string `"m|s"` or `"m | s"`), and `1 {kg * m | s}` (interior formula string). `10m / 1s` is still expression division. `1 kg * m | s` is `(1 kg) * m` then unexpected `|`.

## Unit

```elixir
%Elex.Unit{
  monomial: %{optional(String.t()) => integer()}
}
```

Canonical unit monomial only (zero exponents dropped). Names are not split on trailing digits. `1mm` and `1m * 1m` are both monomials (`%{"mm" => 1}`, `%{"m" => 2}`).

`Elex.Unit.same?/2` compares monomials. `Elex.Unit.convertible?/3` takes the catalog and is true when both units have the same dimension vector (`m` and `km` of `:length`). `Elex.Unit.compatible?/3` maps a unit monomial to a category formula and compares it to a category (`cm | s` vs `:speed`). Inspect always formats the monomial with `|` and `^` (`m^2`, `m | s`, `m | s^2`).

## Dimension

```elixir
%Elex.Dimension{
  monomial: %{optional(atom()) => integer()}
}
```

Category formula returned by `validate` for unitful results (base categories → exponents). Never collapsed to a derived name. Inspect: `length | time`, `length^2`, `length | mass * time^2`. An empty monomial is `number`.

## Quantity

```elixir
%Elex.Quantity{
  value: Decimal.t(),
  unit: Elex.Unit.t()
}
```

## Validate / evaluate

Same functions. Validate returns `%Elex.Dimension{}` for unitful results, or `:decimal` / `:boolean` / `:string`. Optional `category: :speed` checks compatibility with that category’s formula; on success still returns the inferred dimension. Evaluate returns `Decimal` or `%Elex.Quantity{}` whose unit is a unit monomial. Conversion via `unit:` or in-expression `convert/2`.

```elixir
Elex.validate(expr, ctx)
Elex.validate(expr, ctx, category: :speed)

Elex.evaluate(expr, ctx)
Elex.evaluate(expr, ctx, unit: "mm")
Elex.evaluate(expr, ctx, unit: "km | h")
```

`category:` / `unit:` with no catalog, or unknown `category:`, **raises**. Internals thread a **dimension vector** (base category → exponent) plus a concrete unit monomial. The root need **not** match a registered category (`1m * 1m` → `length^2`). Inner nodes may be unnamed (`time^2` inside acceleration).

## Functions

`signature/0` may include `units: :point | :additive | :none | :convert | :wrap | :unwrap`. Omitted means **`:additive`**.

| `units:` | Meaning | Builtins |
|---|---|---|
| `:point` | Same category. Additive: convert later args into the first (then-branch for `if`). Non-additive: `Unit.same?` required; no silent convert. | `abs`, `ceil`, `floor`, `round`, `min`, `max`, `clamp`, `between`, `if`, `coalesce` |
| `:additive` | Reject non-additive categories. Same-category linear args still convert into the first unit before `call/1`. | Custom `double/1` without a flag |
| `:none` | Reject all quantities. | `sqrt`, `pow`, `rem`, `mod`, `%`, strings, `pi` |
| `:convert` | First arg a quantity, second a string target; result unit is the target. | `convert` |
| `:wrap` | Dimensionless number plus a registered name or alias. | `add_unit` |
| `:unwrap` | Quantity → magnitude. | `remove_unit` |

Comparisons follow the `:point` rule (same category; non-additive also same unit) → `:boolean`. Unary minus is a language op, not a function: allowed; keeps the unit. `pi()` is a number.

`convert/2`: first arg a quantity, second a string (symbol or formula); same conversion rules as `evaluate(..., unit:)`. Dim-mismatch wording stays `cannot convert length to mass` (not the root `unit:` “valid X result” line).

`remove_unit/1`: quantity → `Decimal`. `add_unit/2`: number + registered **canonical name or alias** → Quantity of that unit’s category (unregistered formulas such as `"m | s"` are rejected).

Binary `+ − * /` on a non-additive category always error (not a function flag).

Custom functions: set `units:` in `signature/0`. See Advanced guide. `call/1` may receive `%Elex.Quantity{}`. Evaluator aligns later quantity args **only** for `:additive` functions, and for `:point` functions when the category is additive.

## Variables

Optional `category:` on add. Value is unitless **xor** a Quantity/`{number, unit}` matching that category. `{number, unit}` requires a registered **symbol**. `%Elex.Quantity{}` carries a unit monomial of that category. Expression syntax cannot put a unit after a name; use `var * 1mm`.

## Ash

`expected_type` may be a category atom when the context has a catalog (`:length`). That becomes `validate(..., category: :length)` — not a comparison to a returned `:length` atom. Unitless numeric remains `:decimal`.
