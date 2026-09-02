# User flows

Canonical behaviour for unit support. Actor is always a **library caller**. Catalogs in examples are **test/caller fixtures**, not library data.

## Flow 1: Units off (default)

**Precondition:** `Elex.new_context/0`, no catalog

**Steps:**

1. `evaluate("1 + 2", ctx)` → `{:ok, Decimal 3}`
2. `validate("x + 1", ctx)` → `{:ok, :decimal}`

**Error paths:**

- `1cm` / `1 cm` / `width + 2mm` → parse error `unexpected 'cm'` / `unexpected 'mm'`
- `extract_variables("width + 2mm", ctx)` with no catalog → `unexpected 'mm'` (unconsumed identifier-like tokens are unexpected)
- `extract_variables("width + 2mm", ctx)` with a length catalog → `{:ok, ["width"]}`
- `validate(..., category: :length)` or `evaluate(..., unit: "mm")` with no catalog → **raises**

## Flow 2: Register catalog

**Steps:**

1. Register `:length` with conversion default `m`
2. Register `m`, `mm`, `cm`, `ft` with Elex conversions to `m`
3. Attach catalog to context → `{:ok, ctx}`; suffixes parse
4. `Catalog.kind(catalog, :length)` → `{:ok, :base}`

**Error paths:**

- Unit name is a reserved word → registration error
- Name does not start with a letter → registration error
- Second category with the same dimension as an existing one → registration error
- Derived category with no base-hub identity unit (`:area` with only `m2` / `ha`) → `put_units` error

## Flow 3: Same-category add (left-to-right)

**Precondition:** Caller length catalog: `m` (conversion default), `mm`, `cm`, `ft`

**Steps:**

1. `"1m + 1mm"` → Quantity `1.001`, unit monomial `%{"m" => 1}`
2. `"1mm + 1m"` → Quantity `1001`, unit monomial `%{"mm" => 1}` (left unit wins)
3. `"1m + 1ft"` → ft converted into m
4. `validate` → `{:ok, %Elex.Dimension{monomial: %{length: 1}}}` (inspect `length`)

**Error paths:**

- `"1m + 1kg"` → incompatible categories
- `"1m + 2"` → `cannot add length and number` (including `1m + 0`; `1m + 0m` is valid)

## Flow 4: Explicit target unit (simple)

**Steps:**

1. `evaluate("1m + 1mm", ctx, unit: "mm")` → `1001 mm`

**Error paths:**

- Target `kg` → `expression should return a valid mass result` (target’s category)
- Unknown target unit → error
- `unit:` with no catalog → **raises**

## Flow 5: Derived category without auto-naming (area)

**Precondition:** Length conversion-default `m`. `:area` **need not** be registered for validate/evaluate of `1m * 2m`. If `:area` exists, it is derived (`formula: "length * length"`), `Catalog.kind` is `:derived`, and `put_units` requires a base-hub identity unit (`"m * m"` or `"m^2"`). Hub `default:` is the canonical identity (typically `"m^2"`), not an alias. Input aliases are `aliases: ["m2", "sqm"]` on that unit.

**Steps:**

1. `"1m * 2m"` → Quantity `2`, unit monomial `%{"m" => 2}` (inspect `m^2`)
2. Same with `unit: "m^2"` or `unit: "m2"` (alias of `"m^2"`)
3. `"1m2"` / `"1 m^2"` / `"1sqm"` → Quantity `1`, unit monomial `%{"m" => 2}` (inspect `m^2`, never `m2` / `sqm`)
4. `"1m2 / 1m"` → Quantity `1`, unit monomial `%{"m" => 1}` (inspect `m`)
5. `validate` → `{:ok, %Elex.Dimension{monomial: %{length: 2}}}` (inspect `length^2`) even with no `:area`
6. `validate(..., category: :area)` succeeds only if `:area` is registered and its formula is `length^2`

**Error paths:**

- `"1m2"` with no `m2` alias and no canonical unit `m2` → `unknown unit 'm2'`
- `"1m * 1kg"` is valid without `category:` (formula `length * mass`)
- `"1m * 1kg"` with `category: :length` → length was expected, got length * mass

## Flow 6: Unregistered derived combination keeps its monomial

**Precondition:** Area hub is `m * m`. `mm * mm` is not a registered area unit.

**Steps:**

1. `"1mm * 1mm"` → Quantity `1`, monomial `%{"mm" => 2}` (not scaled to `m * m`)
2. `evaluate(..., unit: "m * m")` → `0.000001`, monomial `%{"m" => 2}`
3. `validate` → `length^2` (same as Flow 5)

## Flow 7: Compound result (acceleration)

**Precondition:** Optional `:acceleration = length | time^2`, hub `default: "m | second^2"`. Not required for validate/evaluate of the product.

**Steps:**

1. `"10mm / (1hour * 1hour)"` → Quantity `10`, monomial `%{"mm" => 1, "hour" => -2}` (inspect `mm | hour^2`; not converted to the hub)
2. Same with `unit: "mm | hour^2"` → that formula (component conversion)
3. `unit: "m | s^2"` works when `s` is registered. `"m | s2"` is the symbol `s2` (error unless that name exists). A named alias `10mps2` works if registered.
4. `validate` → `length | time^2`
5. `validate(..., category: :acceleration)` succeeds when that category’s formula is `length | time^2`

**Error paths:**

- `"1hour * 1hour"` alone is valid without `category:` (`time^2`)
- `"1hour * 1hour"` with `category: :acceleration` → acceleration was expected, got time^2

## Flow 8: Caller temperature catalog (non-additive)

**Precondition:** Test registers `:temperature` with `additive: false`, conversion default `C`. `F` stores `to_default` as F→C, e.g. `"(value - 32) * 5 / 9"`. Inverse via `Elex.Inverter` is C→F. Elex does not ship `C`/`F`/`K`.

**Steps:**

1. `evaluate("32F", ctx, unit: "C")` → Quantity `0 C`
2. `evaluate("0C", ctx, unit: "F")` → Quantity `32 F`
3. `1C > 0C` → `true`; `min(1C, 2C)` → `1 C`; `ceil(1.2C)` → `2 C`; `if(true, 1C, 2C)` → `1 C`; `between(50C, 0C, 100C)` → boolean; `-5C` → `−5 C`
4. `min(1C, convert(33F, "C"))` → ~`0.556 C` (both already `C`)

**Error paths:**

- Non-invertible conversion at registration → error
- Offset `F` on an **additive** category → registration error
- `"1C + 2C"`, `"0C + 10F"`, `"2 * 1C"`, `"1C / 1s"`, `"10C / 50C"` → error (non-additive is not a vector)
- `if(true, 1C, 2F)`, `min(1C, 32F)`, `1C > 32F` → error (mixed units; no silent convert)
- Compound `unit:` / `convert` target that includes `F` or `C` (`"F | s"`) → error
- Forgetting `additive: false` on a C-only catalog → `2 * 1C` still works (linear by default)

## Flow 9: Variables

**Steps:**

1. `width` as `:length` with value `10 cm` → accepted
2. `"width + 1mm"` → `10.1 cm`
3. Unitless `count * 1mm` → mm
4. `%Elex.Quantity{}` from evaluate (unit monomial) can be added back with `category:` matching that unit’s category

**Error paths:**

- Category without a unit on the value
- Unit on a unitless variable
- `"width mm"` — units do not follow names

## Flow 10: Scale and cancel

**Steps:**

1. `"2 * 3m"` → `6 m`
2. `"4m / 2m"` → Decimal `2`; `validate` → `:decimal` (empty category formula)
3. `"1m / 10cm"` → Decimal `10`
4. `"(1mm / 1s) * 1s"` → `1 mm` (monomial `%{"mm" => 1}`; **not** snapped to metres)

**Error paths:**

- `"2 + 3m"` → error

## Flow 11: Functions

**Steps:**

1. `abs(-5mm)` → `5 mm`
2. `min(1m, 10cm)` → convert into first arg’s unit → `0.1 m` (also `min(1m, 1km)` — additive, not same symbol)
3. `if(true, 1m, 100cm)` → else into then’s unit → `1 m`
4. `"1m > 10cm"` → `true`; validate `:boolean`
5. `between(50cm, 1m, 2m)` → same category, convert into first arg → `true`/`false` as appropriate
6. `ceil` / `floor` / `round` operate on the **current magnitude** (`ceil(1.2mm)` → `2 mm`)

**Error paths:**

- `sqrt(1m * 1m)` / `sqrt(4mps2)` rejected (no dimensional sqrt)
- `"1m > 5"` rejected
- `if` branches different categories
- `rem` / `mod` / `%` of units rejected

## Flow 12: Derived-unit conversion by components

**Precondition:** Base units and conversions only (`m↔km`, `s↔h`). `:speed = length | time` may be registered for `category:` checks; hub `m | s`. Do **not** register `km/s`, `m/h`, or `km/h`.

**Steps:**

1. `"10m / 1s"` → evaluate monomial `%{"m" => 1, "s" => -1}` (inspect `m | s`; hub is not auto-applied)
2. `unit: "km | s"` → `0.01`, monomial `km | s` (only length converts)
3. `unit: "m | h"` → `36000`, monomial `m | h` (only time converts)
4. `unit: "km | h"` → `36`, monomial `km | h` (both)
5. `validate` → `length | time`
6. `validate(..., category: :speed)` succeeds; `1cm / 1s` is compatible even if `cm/s` is unregistered

**Error paths:**

- `unit: "km"` → `expression should return a valid length result`
- `unit: "m * s"` → `expression should return a valid …` from that target’s category formula
- Unknown symbols in the target formula

## Flow 13: Force — explicit `unit:` to N

**Precondition:** `:force = mass * length | time^2`. Hub `default: "N"`. Registered units: `N` and `"kg * m | s^2"` with `1 N = 1 kg * m | s^2`. The formula unit is the required base-hub identity (`kg`, `m`, `s` hubs). `g * m | s^2` is **not** a registered force unit.

**Steps:**

1. Register as above
2. `"1N"` → Quantity `1`, monomial `%{"N" => 1}`
3. `"1kg * 1m / (1s * 1s)"` → Quantity `1`, monomial `%{"kg" => 1, "m" => 1, "s" => -2}` (inspect `kg * m | s^2`; not auto `N`)
4. `evaluate(..., unit: "N")` → `1`, monomial `%{"N" => 1}` (and `"1g * 1m / (1s * 1s)"` with `unit: "N"` → scaled `N`)
5. `evaluate("1N", ctx, unit: "kg * m | s^2")` → that monomial
6. `validate("1g * 1m / (1s * 1s)")` → `mass * length | time^2` (not `:force`)
7. `validate(..., category: :force)` succeeds (compatible with force’s formula)

**Error paths:**

- Identity references unknown `kg` / `m` / `s`
- Formula does not match `:force`

## Flow 14: Custom functions (docs)

**Steps:**

1. Author reads Advanced / Functions guides: `signature` includes `units: :point | :additive | :none | :convert | :wrap | :unwrap` (default `:additive`). `same_numeric_type/2` for same category; non-additive `:point` also requires `Unit.same?`. `call/1` may receive `%Quantity{}`. Evaluator converts later quantity args into the first arg’s unit only for `:additive` functions and for `:point` on **additive** categories.

## Flow 15: convert/2 in expressions

**Steps:**

1. `convert(1m + 1mm, "mm")` → Quantity `1001`, monomial `%{"mm" => 1}` (same conversion as `evaluate(..., unit: "mm")`)
2. `convert(32F, "C")` → `0 C`; `convert(1m * 2m, "m^2")` → converted to formula target monomial
3. `evaluate(..., unit:)` at the root still works and is equivalent for the whole expression

**Error paths:**

- `convert(1, "mm")` → cannot convert a number
- `convert(1m, "kg")` → wrong category
- `convert(32F, "C") / 1s` → result is still non-additive; `*` `/` error
- Compound target `"F | s"` → non-additive in compound target

## Flow 16: Inspect uses `|` and `^`

**Steps:**

1. `"1m * 2m"` inspects as `#Elex.Quantity<2 m^2>`
2. `"10m / (1s * 1s)"` inspects as `#Elex.Quantity<10 m | s^2>`
3. `"1N"` inspects as `#Elex.Quantity<1 N>` (monomial with a single exponent-1 symbol)

## Flow 17: add_unit / remove_unit

**Precondition:** Temperature catalog (`additive: false`) and length catalog.

**Steps:**

1. `remove_unit(2C)` → Decimal `2`
2. `add_unit(5, "C")` → `5 C`
3. `add_unit(remove_unit(2C) + remove_unit(3C), "C")` → `5 C`
4. `remove_unit(1mm)` → Decimal `1`; `add_unit(10, "mm")` → `10 mm` (helpers work on linear units too)
5. `1m + 1mm` still works without helpers

**Error paths:**

- `remove_unit(1)` → cannot remove unit from a number
- `add_unit(1C, "F")` → already unitful
- `add_unit(1, "nope")` → unknown unit
- `add_unit(1, "m | s")` → not a registered name (formulas are braced literals / `convert` / `1m / 1s` unless `"m | s"` is registered)

## Flow 18: Function `units:` default

**Steps:**

1. Builtins `min` / `between` / `ceil` are `:point` — `min(1m, 1km)` converts; `min(1C, 32F)` errors
2. Unmarked custom `double/1` is `:additive` — `double(1m)` OK; `double(1C)` errors
3. `sqrt` is `:none` — unitful args still error

## Flow 19: Derived identity at put_units

**Precondition:** `:length` hub `m` registered. Caller adds `:area` with `formula: "length * length"`, `default: "m2"`, unit `m2` only (canonical `m2`, no `"m * m"` / `"m^2"`).

**Steps:**

1. `put_units` → `{:error, "derived category :area needs a registered unit matching the base hubs (e.g. \"m * m\")"}`
2. Register `"m * m"` (or `"m^2"`) with a conversion to the hub → `put_units` → `{:ok, ctx}`
3. `Catalog.kind(catalog, :area)` → `{:ok, :derived}`
4. `evaluate("1m * 1m", ctx, unit: "m2")` and `evaluate("1m2", ctx, unit: "m^2")` both succeed (identity walk)

**Error paths:**

- Identity whose dimension is not `length^2` → formula-dimension error at `add_unit`
- Hub `ha` without `"m * m"` / `"m^2"` → same `put_units` error as step 1 (no evaluate-time “needs a formula unit” after a successful attach)

## Flow 20: Canonical power units and input aliases

**Precondition:** `:length` hub `m` (and `cm`). `:area` with `formula: "length * length"`, `default: "m^2"`. Units: `"m^2"` with `aliases: ["m2", "sqm"]` (`to_default: "value"`); `"cm^2"` with `aliases: ["cm2"]` (conversion to the hub).

**Steps:**

1. `evaluate("5 m2")` / `evaluate("5 m^2")` / `evaluate("5 sqm")` → `#Elex.Quantity<5 m^2>` (`%{"m" => 2}`)
2. `evaluate("5 cm2")` → `#Elex.Quantity<5 cm^2>` (`%{"cm" => 2}`)
3. `Unit.same?(evaluate("1m2"), evaluate("1m * 1m"))` → true
4. `add_unit(5, "m2")` and `add_unit(5, "m^2")` wrap to `5 m^2`
5. `1ha` and `1N` (if registered as canonical names, not aliases) inspect as `ha` / `N`

**Error paths:**

- `aliases: ["m2"]` when `m2` is already a unit or alias → registration error
- `default: "m2"` while canonical name is `"m^2"` → `default:` not among the category’s units
- `"5m ^ 2"` → `spaces around '^' are not a power suffix; write 5m^2`
- `"5 m2"` with no alias and no canonical `m2` → `unknown unit 'm2'`

## Flow 21: `add_unit/3` and category `identity:`

**Precondition:** `:length` hub `m`, `:mass` hub `kg`, `:time` hub `s`.

**Steps:**

1. `Catalog.add_unit(catalog, :length, "m")` succeeds (`to_default` is `"value"`)
2. `add_category(:force, formula: "mass * length | time^2", default: "N", identity: "kg * m | s^2")` then `add_unit(:force, "N")` then `add_unit(:force, "kg * m | s^2")` then `put_units` → `{:ok, ctx}` with both units
3. `evaluate("1N")` → `#Elex.Quantity<1 N>`
4. `evaluate("1kg * 1m / (1s * 1s)", ctx, unit: "N")` → `1 N`
5. `evaluate(~S|convert(1N, "kg * m | s^2")|)` → `1 kg * m | s^2`
6. Area with `default: "m^2"` needs no `identity:`; `add_unit(:area, "m^2", aliases: ["m2", "sqm"])` attaches
7. Area with `default: "ha"` and `identity: "m^2"` plus `add_unit(:area, "m^2", "value / 10000")` attaches; `1ha` inspects as `ha`

**Error paths:**

- Force with `default: "N"` and neither `identity:` nor a `"kg * m | s^2"` unit → `put_units` error (same class as Flow 19)
- Force with `identity: "kg * m | s^2"` and only unit `"N"` → same `put_units` error (`identity:` does not substitute for a registered identity unit)
- `identity:` on `:length` → registration error
- `identity: "m^2"` on `:force` (wrong monomial) → registration error
- `ha` hub with `identity: "m^2"` but no `"m^2"` unit → same `put_units` error; callers must register the scaled identity unit. Elex does not invent a scale.

## Flow 22: Compound literal suffixes (pipe and braces)

**Precondition:** `:length` hub `m`, `:time` hub `s`, `:mass` hub `kg`. Units `m`, `s`, `kg` registered. No named `"m | s"` unit required.

**Steps:**

1. `evaluate("3 m|s", ctx)` / `"3m|s"` / `"3 m | s"` → `#Elex.Quantity<3 m | s>` (`%{"m" => 1, "s" => -1}`)
2. `evaluate("3 m|s^2", ctx)` → `#Elex.Quantity<3 m | s^2>`
3. `evaluate("1 {kg * m | s}", ctx)` / `"1{kg * m | s}"` → `#Elex.Quantity<1 kg * m | s>`
4. `evaluate("1kg * 1m|s", ctx)` → same monomial as step 3
5. `validate("3 m|s", ctx)` → `%Elex.Dimension{monomial: %{length: 1, time: -1}}`
6. Inspect of step 3 is `#Elex.Quantity<1 kg * m | s>` (no braces)

**Error paths:**

- `"1 kg * m | s"` → `unexpected '|'; compound units belong in braces, for example 1 {kg * m | s}` (`*` is expression multiply by variable `m`)
- `"3 m | s * s"` and `"3 m | s * h"` (when `h` is a registered unit) → parse error: unbraced pipe suffixes cannot continue with `* <unit>`; write a power on the denominator or a braced formula (`3 m|s^2` or `3 {m | s * s}`). `"3 m | s * 2"` is `(3 m|s)*2`
- `"1 {kg * foo | s}"` → `unknown unit 'foo'` (or unknown unit naming that suffix)
- `"1 {kg * m | s"` → parse error (unclosed brace)
- `"(1+2) {m | s}"` → unexpected `{` (suffixes on numeric literals only)
- `"1 {m / s}"` → invalid formula (no `/` in formula language)
- `"1 m|m"` / `"1 {m^0}"` → invalid formula (empty unit)
- `"1 m|mm"` / `"1 {ha | m^2}"` / `"1 {N * s^2 | kg * m}"` → formula repeats a category in the numerator and denominator (after expanding derived units)
- No catalog: `"3 m|s"` / `"1 {m | s}"` → `unexpected 'm'` / `unexpected '{'`
