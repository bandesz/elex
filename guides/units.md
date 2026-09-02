# Units

Elex does not ship units. Register a catalog and attach it to a context;
until then, `Elex.new_context/0` treats `1cm` as a parse error.

## Registering a catalog

Build an `Elex.Units.Catalog`, then put it on the context. `put_units/2`
returns `{:ok, context}` or `{:error, reason}`. Use `put_units!/2` to pipe:

```elixir
alias Elex.Units.Catalog

{:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
{:ok, catalog} = Catalog.add_unit(catalog, :length, "m")
{:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
{:ok, catalog} = Catalog.add_unit(catalog, :length, "cm", "value / 100")
{:ok, catalog} = Catalog.add_unit(catalog, :length, "km", "value * 1000")
{:ok, catalog} = Catalog.add_category(catalog, :time, default: "s")
{:ok, catalog} = Catalog.add_unit(catalog, :time, "s")
{:ok, catalog} = Catalog.add_unit(catalog, :time, "h", "value * 3600")

{:ok, catalog} =
  Catalog.add_category(catalog, :speed, formula: "length | time", default: "m | s")

{:ok, catalog} = Catalog.add_unit(catalog, :speed, "m | s")

{:ok, context} = Elex.Context.put_units(Elex.new_context(), catalog)
```

`add_category/3` takes a category atom and `default:` — the conversion-default
unit (the **hub** used when converting between units of that category).
`additive:` defaults to `true`. `add_unit/3` omits conversion (`"value"`).
An explicit conversion is an Elex expression that converts `value` **to that
default**. Optional `aliases:` are extra input spellings of that canonical
name (`add_unit(catalog, :area, "m^2", aliases: ["m2", "sqm"])`). The inverse
is derived automatically. Offset conversions (`to_default(0) ≠ 0`) require
`additive: false`.

Unit symbols start with a letter and may contain letters, digits, and
underscores (`mm`, `mps2`, `N`). Digits are part of a **canonical name**:
`s2` is not `s^2`, and a unit registered as `"m2"` stays `m2`. Register
`"m^2"` with `aliases: ["m2", "sqm"]` when you want `5 m2` and `5 sqm` to
mean square metres. Derived categories also allow **formula-shaped** names
(`"m^2"`, `"m | s"`); base categories reject those (`invalid unit name 'm^2'`).
They are case-sensitive. Reserved words
(`and`, `or`, `not`, `null`, `true`, `false`, `yes`, `no`, `e`, `E`) cannot be unit names. `e` and `E` are reserved so scientific notation (`1e3mm`) stays unambiguous.

Each category must have a unique dimension vector. A second category with the
same dimension as an existing one is a registration error (for example torque
and energy both as `mass * length * length | time * time`). Register those as
separate **base** categories if you need both.

## Quantities and validation

With a catalog attached, a numeric literal may be followed by a unit suffix:
a registered name or alias (`10mm` or `10 mm`), a power (`5 m^2`), an
unbraced pipe (`3 m|s`, `3 m | s^2`), or a braced formula (`1 {kg * m | s}`).
`Elex.validate/2` returns a **category formula** as
`%Elex.Dimension{}` (`length`, `length | time`, `length^2`) — never a derived
atom such as `:speed`. Optional `category: :speed` checks compatibility with
that category's formula; on success validate still returns the inferred
dimension. `Elex.evaluate/2` returns `%Elex.Quantity{}` whose unit is a
**unit monomial** (`cm | s`, `m^2`) instead of a bare `Decimal` when the
result has a unit. `category:` and `unit:` raise `ArgumentError` when the
context has no catalog.

```elixir
{:ok, %Elex.Dimension{monomial: %{length: 1}}} = Elex.validate("1mm", context)
{:ok, :decimal} = Elex.validate("1", context)

{:ok, dim} = Elex.validate("1cm / 1s", context, category: :speed)
# dim => #Elex.Dimension<length | time>

{:ok, qty} = Elex.evaluate("1cm / 1s", context)
# qty => #Elex.Quantity<1 cm | s>
# qty.unit => %Elex.Unit{monomial: %{"cm" => 1, "s" => -1}}

{:ok, qty} = Elex.evaluate("3 m|s", context)
# qty => #Elex.Quantity<3 m | s>
```

Inspect always formats the monomial with `|` and `^` (`m^2`, `m | s^2`),
not `m * m` or `m / (s * s)`.

## Addition and multiplication are left-to-right

Same-category addition converts the right operand into the **left** unit.
The same conversion applies to overlapping dimensions in `*` and `/`:

```elixir
{:ok, qty} = Elex.evaluate("1m + 1mm", context)
# qty => #Elex.Quantity<1.001 m>

{:ok, qty} = Elex.evaluate("1mm + 1m", context)
# qty => #Elex.Quantity<1001 mm>

{:ok, qty} = Elex.evaluate("1m * 1mm", context)
# qty => #Elex.Quantity<0.001 m^2>
```

A number cannot be added to a quantity (`1m + 2` and `10cm + 0` are both
`cannot add length and number`). Same-category division cancels to a
`Decimal` (`4m / 2m` → `2`).

Comparisons (`<`, `>`, `<=`, `>=`, `==`, `!=`) require the same category.
A **literal** `0` (`0`, `0.0`, `-0`) may stand in for the unique zero of an
**additive** quantity on either side (`10cm > 0`, `0 < 10cm`). Variables
and computed zeros (`10cm > count`, `10cm > (1 - 1)`) stay type errors,
as does any other number (`10cm > 1`).

## Target unit

Pass `unit:` to convert the result after evaluation. The target may be a
registered symbol, an alias, or a formula over registered symbols — you do
not need to register `km | h` as its own unit.

`unit:` and `convert` take unbraced formula strings (`"km | h"`, not
`"km / h"` or `"{m | s}"`). Inside an expression, `convert/2` is the same
conversion as `unit:`:

```elixir
{:ok, qty} = Elex.evaluate("1m + 1mm", context, unit: "mm")
# qty => #Elex.Quantity<1001 mm>

{:ok, qty} = Elex.evaluate(~s[convert(1m + 1mm, "mm")], context)
# qty => #Elex.Quantity<1001 mm>

{:ok, qty} = Elex.evaluate("10m / 1s", context, unit: "km | h")
# qty => #Elex.Quantity<36 km | h>
```

A target of a different category (`unit: "kg"` on a length) is
`expression should return a valid mass result`. The same mismatch from
`convert(1m, "kg")` is `cannot convert length to mass`.

Suffix and formula parse traps are in [Gotchas](#gotchas).

## Derived categories

A derived category is a formula over **base category names** (`length`,
`time` — the category atoms, not unit symbols like `m` or `s`). Derived
category names are not allowed in another formula (`speed | time` is an
error even when `:speed` exists). `default:` is required: the conversion
**hub** used when converting between units of that category — not the unit
evaluate returns. `put_units/2` then requires that hub to be among the
category's registered units, same as a base category, **and** a base-hub
identity. That identity is satisfied when
(a) `default:` parses to the product of the **base hubs** (`"m^2"` when
`:length` defaults to `m`), or (c) a registered unit name parses
to it (`"kg * m | s^2"`). Optional `identity:` on `add_category` names that
product (`identity: "kg * m | s^2"`) and must parse to the same monomial; it
does not substitute for a registered unit. A derived category that has only
aliases (`m2`, `ha`) and none of those cannot attach:
`{:error, "derived category :area needs a registered unit matching the base hubs (e.g. \"m * m\")"}`.
`identity:` is rejected on base categories.

`Catalog.kind/2` is `{:ok, :base}` when there is no `formula:`,
`{:ok, :derived}` when there is, and `:error` if the name is unknown.

`|` is the only fraction bar (`m | s^2`). Multiply with `*`, middot, or
whitespace (`kg m` is `kg * m`). At most one `|`; `/` and parentheses are
invalid (`"km / h"` is not a formula — write `"km | h"`). Use `m | s^2` or `m | s * s` when you mean a squared denominator.
A formula unit cannot place the same category in both the numerator and the
denominator (`N * s | s` and `N * s | hour` are registration errors).
`"m * m"` is valid: both factors are in the numerator.
A formula-shaped unit name (`"cm^2"`) whose components are already
registered must use a conversion that matches those components (`cm` at
`value / 100` means `"cm^2"` is `value / 10000`, not an unrelated scale).

```elixir
{:ok, catalog} =
  Catalog.add_category(catalog, :area,
    formula: "length * length",
    default: "m^2"
  )

{:ok, catalog} =
  Catalog.add_unit(catalog, :area, "m^2", aliases: ["m2", "sqm"])
{:ok, context} = Elex.Context.put_units(Elex.new_context(), catalog)

Catalog.kind(catalog, :length)
# => {:ok, :base}

Catalog.kind(catalog, :area)
# => {:ok, :derived}
```

The **canonical** name is the inspect spelling. `m2` and `sqm` are **input
aliases** of canonical `"m^2"`, not an expansion of trailing digits.
`"5 m2"`, `"5 m^2"`, and `"5 sqm"` all evaluate to `%{"m" => 2}` and inspect
as `m^2`. `N` is canonical — `#Elex.Quantity<1 N>` — not an alias of
`kg * m | s^2`. `default:` must be a **canonical** unit name, not an alias
(`default: "m2"` is an error when `"m^2"` is the registered name). Without
that alias (and without a canonical unit `m2`),
`"5 m2"` is `unknown unit 'm2'`. During `*` `/` an alias expands through the
identity: `"1m2 / 1m"` evaluates as `"1m * 1m / 1m"` → `1 m`. `"1m * 2m"`
validates as `length^2` even without `:area`. Pass `category: :area` when the
result must match that category's formula; on success validate still returns
`length^2`. Evaluate of a product yields a unit monomial
(`%Elex.Unit{monomial: %{"m" => 2}}`), not the hub. Inspect uses `^`.

`1m2 / 1m / 1m` is the number `1`. Named hubs such as `ha` and `N` stay
those names unless they are registered as aliases of a formula unit. Force
is the same sugar: `1N / 1kg` is `1 m | s^2`.

```elixir
{:ok, qty} = Elex.evaluate("1m * 2m", context)
# qty => #Elex.Quantity<2 m^2>

{:ok, qty} = Elex.evaluate("5 m2", context)
# qty => #Elex.Quantity<5 m^2>

{:ok, qty} = Elex.evaluate("5 m^2", context)
# qty => #Elex.Quantity<5 m^2>

{:ok, qty} = Elex.evaluate("1m2 / 1m", context)
# qty => #Elex.Quantity<1 m>

{:ok, qty} = Elex.evaluate("1m * 2m", context, unit: "m2")
# qty => #Elex.Quantity<2 m^2>

{:ok, qty} = Elex.evaluate(~s[convert(1m * 2m, "m^2")], context)
# qty => #Elex.Quantity<2 m^2>
```

Force is the same idea: the product stays a monomial until you convert.
Register `:mass` (and keep `:length` and `:time`) before the derived
category. Pass `identity: "kg * m | s^2"` so the hub `"N"` names that formula —
`s2` would be a different name — and register the identity unit. After adding
units, attach the catalog again with `put_units/2`:

```elixir
{:ok, catalog} = Catalog.add_category(catalog, :mass, default: "kg")
{:ok, catalog} = Catalog.add_unit(catalog, :mass, "kg")

{:ok, catalog} =
  Catalog.add_category(catalog, :force,
    formula: "mass * length | time^2",
    default: "N",
    identity: "kg * m | s^2"
  )

{:ok, catalog} = Catalog.add_unit(catalog, :force, "N")
{:ok, catalog} = Catalog.add_unit(catalog, :force, "kg * m | s^2")
{:ok, context} = Elex.Context.put_units(Elex.new_context(), catalog)
```

```elixir
{:ok, qty} = Elex.evaluate("1N / 1kg", context)
# qty => #Elex.Quantity<1 m | s^2>

{:ok, qty} = Elex.evaluate("1kg * 1m / (1s * 1s)", context)
# qty => #Elex.Quantity<1 kg * m | s^2>

{:ok, qty} = Elex.evaluate("1kg * 1m / (1s * 1s)", context, unit: "N")
# qty => #Elex.Quantity<1 N>

{:ok, qty} = Elex.evaluate("1 {kg * m | s}", context)
# qty => #Elex.Quantity<1 kg * m | s>
```

Numeric literals take a registered **name**, an **alias**, a power suffix
(`10mm`, `10mps2`, `5 m2`, `5 m^2`), an unbraced pipe (`3 m|s`, `3 m | s^2`),
or a braced formula (`1 {kg * m | s}`). A compound target such as `m | s^2`
on `unit:` / `convert` stays an unbraced formula string. Register `:length`
and `:time` first, then a named unit when you want a compact token:

```elixir
{:ok, catalog} =
  Catalog.add_category(catalog, :acceleration,
    formula: "length | time^2",
    default: "m | s^2"
  )

{:ok, catalog} = Catalog.add_unit(catalog, :acceleration, "m | s^2", "value")
{:ok, catalog} = Catalog.add_unit(catalog, :acceleration, "mps2", "value")
{:ok, context} = Elex.Context.put_units(Elex.new_context(), catalog)
```

`10mps2` is the named unit. `"m | s2"` looks up the name `s2` and is an
error unless that name exists.

Without `category:`, an unregistered product such as `time * time` is valid
and returns that formula (`time^2`). Pass `category: :acceleration` when the
result must match a registered category.

**Register the identity unit when the hub is not that formula.** `identity:
"m^2"` without a registered `"m^2"` unit is a `put_units` error — the same
class as a derived category with no identity. That is required for Newton
(`N` plus `"kg * m | s^2"` at scale 1) and for hectare (`ha` plus `"m^2"`
at `"value / 10000"`). Elex does not invent `10000`. When the hub is not 1:1
with the identity, the scale lives on the identity unit. That is a
separate `:area` catalog, not added next to a `"m^2"` hub:

```elixir
{:ok, ha_catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
{:ok, ha_catalog} = Catalog.add_unit(ha_catalog, :length, "m")

{:ok, ha_catalog} =
  Catalog.add_category(ha_catalog, :area,
    formula: "length * length",
    default: "ha",
    identity: "m^2"
  )

{:ok, ha_catalog} = Catalog.add_unit(ha_catalog, :area, "ha")
{:ok, ha_catalog} = Catalog.add_unit(ha_catalog, :area, "m^2", "value / 10000")
{:ok, ha_context} = Elex.Context.put_units(Elex.new_context(), ha_catalog)
```

```elixir
{:ok, qty} = Elex.evaluate("1ha", ha_context)
# qty => #Elex.Quantity<1 ha>
```

## Functions

`abs`, `ceil`, `floor`, and `round` keep the argument’s unit and operate on the
**current magnitude** — they do not convert to the category hub first.
That includes non-additive points: `floor(1.8C)` is `1 C`, not a conversion
to another temperature scale.

```elixir
{:ok, qty} = Elex.evaluate("ceil(1.2mm)", context)
# qty => #Elex.Quantity<2 mm>

{:ok, qty} = Elex.evaluate("round(1.5mm)", context)
# qty => #Elex.Quantity<2 mm>
```

`min`, `max`, `clamp`, `if`, `coalesce`, and `between` (`:point` functions)
require the same category. On additive categories they convert later quantity
arguments into the first quantity argument's unit — `min(1m, 1km)` is
valid, and `if(false, 1m, 100cm)` returns metres. A literal `0` (`0`, `0.0`,
`-0`) is also allowed next to an additive quantity (`min(10cm, 0)`,
`clamp(width, 0, 10cm)`, `if(width > 0, width, 0)`); variables and `1 - 1`
are not. `between(50cm, 1m, 2m)` is `false` because 50 cm is below 1 m after
converting into centimetres. On non-additive categories the units must
already match; `min(1C, 32F)` is an error. `sqrt`, `pow`, `rem`, `mod`, and
`%` reject unitful arguments.

## Variables

Unit suffixes belong on numeric literals, not on names. Declare a variable's
category and give it a unitful value:

```elixir
{:ok, context} = Elex.add_variable(context, "width", {10, "cm"}, category: :length)
{:ok, qty} = Elex.evaluate("width + 1mm", context)
# qty => #Elex.Quantity<10.1 cm>
```

A unitless number can still scale a quantity (`count * 1mm`). Passing a
quantity from `evaluate` back into `add_variable` works when `category:`
matches that unit's category. `"width mm"` is a parse error — units do not
follow names.

`Catalog.add_unit/3` registers a unit on a catalog. The expression function
`add_unit(value, unit)` wraps a number as a quantity of a
registered **canonical name or alias**. They are not interchangeable.
See [Non-additive categories](#non-additive-categories).

## Non-additive categories

Categories are additive by default. Temperature (and gauge pressure) are
**points**, not vectors: register them with `additive: false`. Offset
conversions (`to_default(0) ≠ 0`) are allowed only on non-additive
categories. Elex does not ship `C`, `F`, or `K` — this is a caller catalog:

```elixir
alias Elex.Units.Catalog

{:ok, catalog} =
  Catalog.add_category(Catalog.new(), :temperature, default: "C", additive: false)

{:ok, catalog} = Catalog.add_unit(catalog, :temperature, "C", "value")
{:ok, catalog} = Catalog.add_unit(catalog, :temperature, "F", "(value - 32) * 5 / 9")

{:ok, context} = Elex.Context.put_units(Elex.new_context(), catalog)

{:ok, qty} = Elex.evaluate("32F", context, unit: "C")
# qty => #Elex.Quantity<0 C>

{:ok, qty} = Elex.evaluate("0C", context, unit: "F")
# qty => #Elex.Quantity<32 F>
```

Non-additive quantities reject binary `+ − * /`, including same-unit
addition and scaling:

```elixir
Elex.evaluate("1C + 2C", context)    # error
Elex.evaluate("0C + 10F", context)   # error
Elex.evaluate("2 * 1C", context)     # error
Elex.evaluate("1C / 1s", context)    # error
Elex.evaluate("10C / 50C", context)  # error
```

Same-unit **point** operations are allowed: comparison, unary minus, and
`:point` builtins (`min`, `max`, `if`, `between`, `clamp`, `ceil`, `floor`,
`round`, `abs`).
Mixing units of a non-additive category is not — there is no silent F→C.
Linear `:point` functions still convert:

```elixir
Elex.evaluate("1C > 0C", context)        # {:ok, true}
Elex.evaluate("1C > 0", context)         # error (unitless 0 is not unique across C/F/K)
Elex.evaluate("min(1C, 0)", context)     # error
Elex.evaluate("min(1C, 2C)", context)    # {:ok, #Elex.Quantity<1 C>}
Elex.evaluate("ceil(1.2C)", context)     # {:ok, #Elex.Quantity<2 C>}
Elex.evaluate("-5C", context)            # {:ok, #Elex.Quantity<-5 C>}
Elex.evaluate("min(1C, 32F)", context)   # error (mixed units)
```

Length examples need a length catalog (`m`, `km`, `mm`), not this
temperature-only context:

```elixir
{:ok, length_catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
{:ok, length_catalog} = Catalog.add_unit(length_catalog, :length, "m", "value")
{:ok, length_catalog} = Catalog.add_unit(length_catalog, :length, "km", "value * 1000")
{:ok, length_catalog} = Catalog.add_unit(length_catalog, :length, "mm", "value / 1000")
{:ok, length_context} = Elex.Context.put_units(Elex.new_context(), length_catalog)

Elex.evaluate("min(1m, 1km)", length_context)  # {:ok, #Elex.Quantity<1 m>}
```

Convert a reading explicitly with `convert/2` or `unit:`. Compound targets
that include a non-additive symbol (`"F | s"`) also error.

```elixir
Elex.evaluate(~s[min(1C, convert(33F, "C"))], context)
# both already C
```

Arithmetic on magnitudes uses the expression function `remove_unit` /
`add_unit` (not `Catalog.add_unit/3`, which registers a catalog unit). The
second argument of `add_unit` is a registered **canonical name or alias**
(including a formula-shaped name such as `"m | s"` or `"m^2"` once
registered). An unregistered formula is an error:

```elixir
Elex.evaluate(~s[add_unit(remove_unit(2C) + remove_unit(3C), "C")], context)
# qty => #Elex.Quantity<5 C>
```

Helpers work on linear units too, once those symbols are registered.
They wrap or strip a name without converting: `add_unit(remove_unit(1km), "m")`
is `1 m`, not `1000 m`. Use `convert` to change units.

```elixir
Elex.evaluate("remove_unit(1mm)", length_context)
# => #Decimal<1>

Elex.evaluate(~s[add_unit(10, "mm")], length_context)
# => #Elex.Quantity<10 mm>
```

`add_unit(1, "m | s")` errors unless `"m | s"` is registered — unregistered
formulas belong on `convert` or `10 * 1m / 1s`. Already-unitful `add_unit`
and `remove_unit` of a number also error.

Forgetting `additive: false` on a C-only catalog leaves `2 * 1C` legal
(linear by default). Offset `F` on an additive category is a registration
error.

Rates belong in a **linear** category with named units (`Cps`), not `C | s`.

## Gotchas

These traps apply to unit suffixes on numeric literals and to `unit:` /
`convert` formula strings.

### `s2` is a name, not an exponent

Integer exponents use `^` in formulas (`m | s^2`) and on numeric literals
(`5 m^2`, `5m^2` — positive integer). `s2` is the registered name `s2`.

### Spaces around `^` are not a suffix

`5m ^ 2` is not `5m^2`. The error hints to write `5m^2`.

### `/` is division, not "per"

`10m / s` is metres divided by the variable `s`. Write `10 m|s` or
`10 {m | s}` for metres per second.

### Unbraced pipes do not continue with `* <unit>`

`3 m | s * 2` is six metres per second. `3 m | s * s` and `3 m | s * h`
(when `h` is a registered unit) are parse errors. Write `3 m|s^2` or
`3 {m | s * s}`.

### Multi-factor units need braces in expressions

`1 kg * m | s` is invalid: `*` is expression multiply, so this is
`(1 kg) * m` then unexpected `|`. Write `1 {kg * m | s}` or
`1kg * 1m|s`.

### Inspect of a Quantity is not an expression

Inspect never inserts `{}`. Copying a multi-factor inspect into an
expression needs braces (`1 {kg * m | s}`) or factor arithmetic
(`1kg * 1m|s`):

```elixir
#Elex.Quantity<1 m | s>
#Elex.Quantity<1 kg * m | s>
```

### A cancelled formula unit is a syntax error

A formula that cancels to nothing (`1 m|m`, `1 {m^0}`) or places the same
category in both the numerator and the denominator — including after
expanding derived units (`1 m|mm`, `1 {ha | m^2}`,
`1 {N * s^2 | kg * m}`) — is a syntax error. Empty units are not allowed.

Arithmetic cancel is different: `1m / 1m` and `1ha / 1 {m^2}` evaluate to
decimals.

### `unit:` / `convert` reject `/` and braces

Write `"km | h"`. `"km / h"` and `"{m | s}"` are invalid target strings.

## What to read next

- `Elex.Units.Catalog` — category and unit registration
- `Elex.Quantity` — evaluated unitful results
- `Elex.Unit` — unit monomial on a quantity (`convertible?/3`, `compatible?/3`)
- `Elex.Dimension` — category formula returned by `validate`
- [Getting Started](getting-started.md) — contexts, validate, and evaluate
- [Functions](functions.md) — which built-ins accept quantities
- [Advanced Topics](advanced.md) — custom functions with units
- [Ash Integration](ash-integration.md) — `expected_type` may be a category
  atom when the context has a catalog
