# Data flow

## Registration

Caller builds `Elex.Units.Catalog` and `put_units` → `{:ok, context}`. Registration must succeed entirely: names, aliases, reserved words, conversion parse + invert, formula components exist, `default:` is a **canonical** unit name of that category (not an alias), identities match the category dimension, **dimension vectors are unique**, and each **derived** category has a base-hub identity (`default:` name parses to the identity monomial, or a matching unit name). Optional `identity:` does not substitute for that unit. Failure → no catalog attached.

Derived `add_category` uses `formula:` over base category names, `default:` (hub), and optional `identity:` (unit formula of the base-hub product). `Catalog.kind/2` is `:base` or `:derived`. `add_unit/3` omits conversion (`"value"`). `add_unit` optional `aliases:` are symbol-pattern input names. `additive:` defaults to `true`; offset `to_default` on an additive category is a registration error.

## Parse

- `units: nil` — unitless combinators; `10mm` and `width + 2mm` are unexpected identifiers.
- Catalog present — optional unit **name, alias, power suffix, unbraced pipe, or braced formula** after a number → `{:unit, decimal, "mm"}` / `"m2"` / `"m^2"` / `"m|s"` / `"kg * m | s"`. Unknown symbol → parse error. `10 + mm` is still number plus variable/identifier. `1 kg * m | s` does not consume `|` as a suffix.

## Validate

Walk AST; each numeric node has `{dim, monomial}`.

| Node | Dim / type |
|---|---|
| `{:unit, _, "mm"}` | Look up symbol; dim and category of that unit |
| `Decimal` | Dimensionless |
| `{:var, name}` | Variable’s declared category (or dimensionless); monomial from the value’s unit when unitful |
| `+` / `-` | Additive categories only. Dims equal and not mixed with dimensionless; result dim = left; type = category. Non-additive operand → error |
| `*` / `/` | Additive only. Add/subtract exponent maps; non-additive operand → error |
| Unary `-` | Same dim/unit as the operand (point op) |
| Root / `if` / `min` / `max` / `between` result | Dim zero → `:decimal`. Non-zero → category formula (need not be a registered category). Optional `category:` must match |
| Compare / `:point` functions | Same category; if non-additive, monomials `Unit.same?` → `:boolean` or that category |
| `:additive` functions | Non-additive operand → error |
| `:none` functions | Any quantity → error |
| `remove_unit` | Quantity → `:decimal` |
| `add_unit` | Dimensionless + registered symbol → that unit’s category |

Return `{:ok, %Elex.Dimension{}}` for unitful results, or `:decimal` / `:boolean` / `:string`. Optional `category:` is a compatibility check only.

## Evaluate

Same walk with values. Same-category conversion of a **point**: to category hub via the stored Elex expression, then inverse to the target unit (actual value, not `convert(1)` as a scale).

- Additive same-category `A op B`: convert B into A’s unit; result monomial is A’s. Non-additive binary `+ − * /` never convert.
- Overlapping same-category dimensions in `*` `/`: convert the right-hand unit into the left symbol before combining (`1m * 1mm` is `0.001 m^2`).
- Dimensionless `*`/`/` with an **additive** unit: keep the unit. Non-additive `*` `/` (including `2 * 1C`) errors.
- `:point` functions on an additive category: convert later args into the first/then unit. On a non-additive category: do not convert; units already match.
- Same-category `/` that cancels: `Decimal`.
- `*`/`/` of quantities: merge monomials (`(1mm / 1s) * 1s` → `%{"mm" => 1}`). Do not convert through the hub. Same-category symbols (including `1 mm * 2m / 1m`) convert the right factor into the left symbol then cancel. A quantity built from an alias already has the canonical monomial (`1m2` → `%{"m" => 2}`). Named derived hubs (`N`) still expand to the base-hub identity during `*` `/` (`1N / 1kg` → `%{"m" => 1, "s" => -2}`).
- `unit:` option and `convert/2`: parse target with the `|` formula grammar; every **symbol** is a catalog name (no trailing-digit expansion); combined dim must match. Named and formula targets both convert through the derived identity (base-hub product) then component scale `convert(1)` (linear; offsets are forbidden on additive categories). Non-additive symbols in a compound target error. Named `convert(32F, "C")` is allowed (point map through the hub). Target need not be a single registered derived name (`km | h` is fine if `km` and `h` exist). Result unit is always that target monomial. `"km | h"` and `"km|h"` are `Unit.same?`. Inspect uses `|` and `^`. Root `unit:` dim mismatch names the **target**’s category.

- `remove_unit` returns the quantity’s `.value` as a `Decimal`. `add_unit` wraps a number as `%Elex.Quantity{}` with the **canonical** monomial of the named unit or alias (`add_unit(5, "m2")` → `%{"m" => 2}`).

## Target unit parsing

`unit: "mm"`, `unit: "km | h"`, `unit: "m | s^2"`, and `convert(x, "…")` use the formula parser (symbols, `*`, middot, whitespace, `|`, `^`), not the full expression language. No `/`, parentheses, or numeric coefficients (`2m` is invalid as a target). Trailing digits are part of a symbol (`s2` ≠ `s^2`).
