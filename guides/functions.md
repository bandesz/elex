# Functions

All built-in functions are registered automatically in contexts created with
`Elex.new_context/0`. This page lists every function with its signature and a
brief description.

For usage examples, see the `Elex.Functions.*` module documentation or try
functions in `Elex.evaluate/2`.

## Math functions

| Function | Description |
|----------|-------------|
| `abs(x)` | Absolute value |
| `ceil(x)` | Round up to the nearest integer |
| `floor(x)` | Round down to the nearest integer |
| `round(x)` | Round to the nearest integer |
| `sqrt(x)` | Square root |
| `pow(base, exp)` | Exponentiation (`base` raised to `exp`) |
| `rem(a, b)` | Remainder; sign follows the dividend (same as `%`) |
| `mod(a, b)` | Floored modulo; sign follows the divisor |
| `max(a, b, …)` | Largest of two or more numbers or same-category quantities (variadic) |
| `min(a, b, …)` | Smallest of two or more numbers or same-category quantities (variadic) |
| `clamp(x, min, max)` | Clamp `x` to an inclusive `[min, max]` range |
| `convert(value, unit)` | Convert a quantity into a named unit or formula (in-expression `unit:`) |
| `add_unit(value, unit)` | Wrap a number as a quantity of a registered name or alias |
| `remove_unit(value)` | Magnitude of a quantity as a number |
| `between(x, low, high)` | `true` when `x` is in the inclusive `[low, high]` range |
| `pi()` | Mathematical constant π |
| `if(cond, a, b)` | Conditional; short-circuits; both branches must share a type |

### `rem` vs `mod` vs `%`

All three perform division-related operations on decimals, but they differ in
how they handle signs:

```elixir
# rem and % — sign follows the dividend
Elex.evaluate("rem(-10, 3)", context)   # #Decimal<-1>
Elex.evaluate("-10 % 3", context)       # #Decimal<-1>

# mod — sign follows the divisor (floored modulo)
Elex.evaluate("mod(-10, 3)", context)   # #Decimal<2>
```

`rem`, `mod`, and `%` reject unitful arguments.

### `clamp` and `between`

`clamp(x, min, max)` returns `x` bounded to `[min, max]`. Returns an error when
`min > max`.

`between(x, low, high)` returns `true` when `low <= x <= high`, and `false`
otherwise. Also returns an error when `low > high`.

With a unit catalog, `between` accepts same-category quantities. On additive
categories it converts later arguments into the first argument’s unit
(`between(50cm, 1m, 2m)` is `false` — 50 cm is below 1 m). `clamp`, `min`,
and `max` do the same: `min(1m, 1km)` is valid. A literal `0` (`0`, `0.0`,
`-0`) may stand in for the unique zero of an additive quantity
(`clamp(width, 0, 10cm)`, `if(width > 0, width, 0)`). On non-additive
categories the units must already match — `min(1C, 32F)` is an error. See
[Units](units.md) for `ceil` / `round` on the current magnitude and for
`additive: false`.

### `convert`

`convert(value, unit)` is the in-expression form of `evaluate(..., unit:)`.
`value` must be unitful; `unit` is a string (registered name or formula).

```elixir
alias Elex.Units.Catalog

{:ok, catalog} = Catalog.add_category(Catalog.new(), :length, default: "m")
{:ok, catalog} = Catalog.add_unit(catalog, :length, "m", "value")
{:ok, catalog} = Catalog.add_unit(catalog, :length, "mm", "value / 1000")
{:ok, context} = Elex.Context.put_units(Elex.new_context(), catalog)

{:ok, qty} = Elex.evaluate(~s[convert(1m + 1mm, "mm")], context)
# qty => #Elex.Quantity<1001 mm>

# Same conversion at the root:
{:ok, qty} = Elex.evaluate("1m + 1mm", context, unit: "mm")
# qty => #Elex.Quantity<1001 mm>
```

The result stays in that category. A non-additive result stays
non-additive, so `convert(32F, "C") / 1s` is an error. A compound target
that includes a non-additive symbol (`"F | s"`) is also an error
(`cannot use non-additive unit 'F' in a compound target`), even when the
dimensions would not match.

`convert` declares `units: :convert`, `add_unit` `units: :wrap`, and
`remove_unit` `units: :unwrap`. Those policies are what allow them to take
temperature quantities — not a built-in name exemption. Custom functions
that need the same behaviour set the same `units:` values.

`abs`, `ceil`, `floor`, `round`, `min`, `max`, `clamp`, `between`, `if`,
and `coalesce` declare `units: :point`. They keep the argument’s unit and
operate on the current magnitude, including non-additive points
(`floor(1.8C)` is `1 C`). `sqrt`, `pow`, `pi`, `rem`, `mod`,
and the string functions declare `units: :none`.

### `add_unit` and `remove_unit`

This is the **expression** function `add_unit/2`, not
`Catalog.add_unit/3` (which registers a unit on a catalog).

`remove_unit(2C)` returns the magnitude as a `Decimal`. `add_unit(5, "C")`
wraps a number as a quantity of a registered **canonical name
or alias** (including a formula-shaped name such as `"m | s"` once
registered). Together they are how you add temperatures:

```elixir
alias Elex.Units.Catalog

{:ok, catalog} =
  Catalog.add_category(Catalog.new(), :temperature, default: "C", additive: false)

{:ok, catalog} = Catalog.add_unit(catalog, :temperature, "C", "value")
{:ok, context} = Elex.Context.put_units(Elex.new_context(), catalog)

{:ok, qty} =
  Elex.evaluate(~s[add_unit(remove_unit(2C) + remove_unit(3C), "C")], context)
# qty => #Elex.Quantity<5 C>
```

`remove_unit(1)` and `add_unit(1C, "F")` error (`add_unit cannot wrap a
quantity that already has a unit`). `add_unit(1, "m | s")` is
an error unless that string is a registered unit name — use `convert` or
`10 * 1m / 1s`. Helpers work on linear units too (`remove_unit(1mm)`,
`add_unit(10, "mm")`). They wrap or strip a registered name only —
`add_unit(remove_unit(1km), "m")` is `1 m`, not `1000 m`. Use `convert`
to change units.

### Examples

```elixir
context = Elex.new_context()

{:ok, result} = Elex.evaluate("max(10, 20)", context)           # #Decimal<20>
{:ok, result} = Elex.evaluate("max(3, 7, 9)", context)           # #Decimal<9>
{:ok, result} = Elex.evaluate("abs(-5)", context)                  # #Decimal<5>
{:ok, result} = Elex.evaluate("pow(2, 3)", context)              # #Decimal<8>
{:ok, result} = Elex.evaluate("clamp(15, 0, 10)", context)      # #Decimal<10>
{:ok, result} = Elex.evaluate("between(5, 0, 10)", context)    # true
{:ok, result} = Elex.evaluate("if(10 > 5, 1, 0)", context)      # #Decimal<1>
{:ok, result} = Elex.evaluate("pi()", context)                    # #Decimal<3.14159…>
```

## String functions

| Function | Description |
|----------|-------------|
| `concat(...)` | Concatenate zero or more strings (variadic) |
| `length(s)` | Character count (returns a decimal) |
| `contains(haystack, needle)` | `true` when `needle` is a substring of `haystack` |
| `match(text, pattern)` | `true` when `text` matches the regex `pattern` |
| `starts_with(s, prefix)` | Prefix test |
| `ends_with(s, suffix)` | Suffix test |
| `lower(s)` | Lowercase transform |
| `upper(s)` | Uppercase transform |
| `trim(s)` | Remove leading and trailing whitespace |
| `coalesce(a, b, …)` | First non-null argument (variadic; short-circuits). With units: same category; result unit is the first quantity argument (`coalesce(ceil(1.2m), floor(1.1cm))` is `m`). |

### `match`

`match(text, pattern)` returns `true` when `text` matches the regex `pattern`.
Patterns use [Elixir/PCRE regex syntax](https://hexdocs.pm/elixir/Regex.html). The
match succeeds when the pattern matches **anywhere** in `text` (like
`contains`, not full-string anchoring).

Literal backslashes in patterns must be escaped in the expression string — use
`\\` (see [Expression Language](expression-language.md#strings) for all string
escapes). Invalid patterns are reported at evaluation time, not parse time.

```elixir
context = Elex.new_context()

{:ok, result} = Elex.evaluate(~s[match("hello123", "hello[0-9]+")], context) # true
{:ok, result} = Elex.evaluate(~s[match("abc123", "abc\\\\d+")], context)        # true
{:ok, result} = Elex.evaluate(~s[match("HELLO", "(?i)hello")], context)     # true

{:error, reason} = Elex.evaluate(~s[match("x", "[")], context)
#=> {:error, "...invalid regex pattern..."}
```

### Examples

```elixir
context = Elex.new_context()

{:ok, result} = Elex.evaluate(~s[concat("hello", " world")], context)   # "hello world"
{:ok, result} = Elex.evaluate(~s[length("abc")], context)              # #Decimal<3>
{:ok, result} = Elex.evaluate(~s[contains("hello", "ell")], context)   # true
{:ok, result} = Elex.evaluate(~s[match("hello123", "hello[0-9]+")], context) # true
{:ok, result} = Elex.evaluate(~s[lower("ABC")], context)              # "abc"
{:ok, result} = Elex.evaluate("coalesce(null, 5)", context)            # #Decimal<5>
```

## Custom functions

Implement the `Elex.Function` behaviour and register your module on the
context. `signature/0` may include `units: :point | :additive | :none |
:convert | :wrap | :unwrap` (default **`:additive`**). See
[Advanced Topics](advanced.md#custom-functions)
for how custom functions preserve a unit, convert later quantity arguments,
or reject unitful values. `call/1` may receive `%Elex.Quantity{}`. Unmarked
custom `double(1C)` errors; `double(1m)` works.

Custom functions sit alongside built-ins in the same context and follow the same
validation rules: arguments are type-checked at parse time, then evaluated at
runtime.

## Introspection API

Host applications can build documentation UIs without reaching into
`context.functions` directly:

```elixir
context = Elex.new_context()

# List all registered functions with metadata
Elex.Context.list_functions(context)
#=> [
#     %{module: Elex.Functions.Abs, name: "abs", arity: 1,
#       signature: "abs(x)", description: "returns the absolute value of x",
#       category: :math},
#     %{module: Elex.Functions.Max, name: "max", arity: :variadic, min_arity: 2,
#       signature: "max(a, b, ...)", description: "returns the largest of the given values",
#       category: :math},
#     ...
#   ]

# Distinguish built-ins from custom functions
Elex.list_standard_function_modules()
#=> [Elex.Functions.Abs, Elex.Functions.AddUnit, ...]
```

Each built-in function's `documentation/0` callback includes an optional
`:category` atom (`:math`, `:string`, etc.) so UIs can group functions without
hardcoding names. Custom functions can set `:category` in their own
`documentation/0` implementation.

## Further reading

- [Expression Language](expression-language.md) — operators and types
- [Advanced Topics](advanced.md) — implementing custom functions
- `Elex.Function` — behaviour callbacks and types
