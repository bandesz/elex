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
| `max(a, b, …)` | Largest of two or more numbers (variadic) |
| `min(a, b, …)` | Smallest of two or more numbers (variadic) |
| `clamp(x, min, max)` | Clamp `x` to an inclusive `[min, max]` range |
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

### `clamp` and `between`

`clamp(x, min, max)` returns `x` bounded to `[min, max]`. Returns an error when
`min > max`.

`between(x, low, high)` returns `true` when `low <= x <= high`, and `false`
otherwise. Also returns an error when `low > high`.

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
| `concat(a, b)` | Concatenate two strings |
| `length(s)` | Character count (returns a decimal) |
| `contains(haystack, needle)` | `true` when `needle` is a substring of `haystack` |
| `starts_with(s, prefix)` | Prefix test |
| `ends_with(s, suffix)` | Suffix test |
| `lower(s)` | Lowercase transform |
| `upper(s)` | Uppercase transform |
| `trim(s)` | Remove leading and trailing whitespace |
| `coalesce(a, b, …)` | First non-null argument (variadic; short-circuits) |

### Examples

```elixir
context = Elex.new_context()

{:ok, result} = Elex.evaluate(~s[concat("hello", " world")], context)   # "hello world"
{:ok, result} = Elex.evaluate(~s[length("abc")], context)              # #Decimal<3>
{:ok, result} = Elex.evaluate(~s[contains("hello", "ell")], context)   # true
{:ok, result} = Elex.evaluate(~s[lower("ABC")], context)              # "abc"
{:ok, result} = Elex.evaluate("coalesce(null, 5)", context)            # #Decimal<5>
```

## Custom functions

Implement the `Elex.Function` behaviour and register your module on the
context. See [Advanced Topics](advanced.md#custom-functions) for a complete
example.

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
#=> [Elex.Functions.Abs, Elex.Functions.Between, ...]
```

Each built-in function's `documentation/0` callback includes an optional
`:category` atom (`:math`, `:string`, etc.) so UIs can group functions without
hardcoding names. Custom functions can set `:category` in their own
`documentation/0` implementation.

## Further reading

- [Expression Language](expression-language.md) — operators and types
- [Advanced Topics](advanced.md) — implementing custom functions
- `Elex.Function` — behaviour callbacks and types
