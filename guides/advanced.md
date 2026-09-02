# Advanced Topics

This guide covers lower-level APIs for applications that need direct access to
the parse tree, expression inversion, or custom functions.

## The parse → validate → evaluate pipeline

Most callers use `Elex.evaluate/2`, which runs all three stages. For more
control, use the modules directly:

```elixir
context = Elex.new_context() |> Elex.add_variable!("x", 10)

{:ok, ast, type} = Elex.Parser.parse("x + 5", context)
# type => :decimal

Elex.Evaluator.evaluate(ast, context)
# => {:ok, #Decimal<15>}

Elex.Evaluator.evaluate!(ast, context)
# => #Decimal<15>
```

`Elex.Parser.parse/3` validates by default. Pass `validate: false` to parse
without checking variable types — useful for extracting structure before a
context is fully built:

```elixir
{:ok, ast, nil} = Elex.Parser.parse("x + y", context, validate: false)
Elex.Validator.validate(ast, context)
# => {:ok, :decimal} or {:error, reason}
```

> **Note:** `Elex.Evaluator.evaluate/2` returns `{:ok, result}` or
> `{:error, reason}`. `evaluate!/2` raises `RuntimeError` or `Decimal.Error`.
> `Elex.evaluate/2` is the string-based API and returns the same `{:error,
> reason}` strings without an extra prefix. Prefer the high-level API unless
> you need the AST.

## AST format

The parser produces plain Erlang terms (tagged tuples). Common shapes:

| Form | Meaning |
|------|---------|
| `%Decimal{}` | Decimal literal |
| `true`, `false` | Boolean literal |
| `"string"` | String literal |
| `nil` | Null literal |
| `{:var, "name"}` | Variable reference |
| `{op, [left, right]}` | Binary operator (`:+`, `:-`, `:*`, `:/`, `:%`, comparisons, `and`, `or`) |
| `{:not, operand}` | Logical not |
| `{-, operand}` | Unary minus |
| `{:unit, decimal, "mm"}` | Unit suffix on a numeric literal (`10mm`, `3 m\|s`, `1 {kg * m \| s}`) |
| `{:func, name, arity, args}` | Function call (`name` is a string, `args` is a list of AST nodes) |

Example AST for `max(x, 10) + 1`:

```elixir
{:+, [
  {:func, "max", 2, [{:var, "x"}, #Decimal<10>]},
  #Decimal<1>
]}
```

## Parser debugging

`Elex.Parser.debug/2` exposes raw NimbleParsec output for troubleshooting. It
does not validate against a context:

```elixir
info = Elex.Parser.debug("( 1 + 2")
info.status   # :error
info.rest     # "( 1 + 2"
info.reason   # raw parser message
```

The result is a map documented as `debug_info/0` on `Elex.Parser`. For end-user
error messages, use `Elex.Parser.parse/3` or `Elex.evaluate/2` instead.

## Expression inversion

`Elex.Inverter` solves simple single-variable arithmetic expressions. Given an
AST and a target variable name, it returns an inverted AST representing the
inverse operation.

Supported operations: `+`, `-`, `*`, `/` (with the variable on one side only).

```elixir
alias Elex.{Parser, Inverter}

context = Elex.new_context() |> Elex.add_variable!("value", 0)

{:ok, ast, _} = Parser.parse("value * 2 + 5", context, validate: false)
{:ok, inverted} = Inverter.invert(ast, "value")

# Evaluate inverted AST with a known result to recover the original variable:
result_context = Elex.new_context() |> Elex.add_variable!("value", 21)
Elex.Evaluator.evaluate!(inverted, result_context)
# => #Decimal<8>  (because (8 * 2) + 5 = 21)
```

`Inverter.invert/2` returns `{:error, reason}` when:

- The expression contains more than one variable
- The target variable is not present
- The expression uses unsupported operations (comparisons, functions, etc.)
- Division by zero would occur during inversion

## Custom functions

Implement the `Elex.Function` behaviour with four callbacks:

| Callback | Purpose |
|----------|---------|
| `signature/0` | Function name and arity (or variadic spec) |
| `validate/2` | Type-check unevaluated argument ASTs at parse time |
| `call/1` | Execute with evaluated argument values |
| `documentation/0` | Human-readable signature and description (optional `:category` atom for grouping) |

`call/1` arguments are already evaluated. With a unit catalog they may be
`%Elex.Quantity{}` as well as `Decimal`. Do not pass a quantity to
`Decimal.mult/2` (or similar) — unwrap `.value` first.

`signature/0` may include `units: :point | :additive | :none | :convert |
:wrap | :unwrap`. Omitted `units:` is **`:additive`**.

| `units:` | Meaning |
|----------|---------|
| `:point` | Same category. Result unit is the first **quantity** argument (boolean/`null` args are skipped, so `if(cond, then, else)` uses the then-branch). Additive: convert later quantity args into that unit. Non-additive: `Elex.Unit.same?/2` required; no silent F→C. |
| `:additive` | Reject non-additive arguments. Same-category linear args still convert into the first quantity argument's unit before `call/1`. **Default.** |
| `:none` | Reject all quantities (`sqrt`, `pow`, `pi`, strings). |
| `:convert` | First arg a quantity, second a string target; result unit is the target. |
| `:wrap` | Number plus a registered name or alias (`add_unit`). |
| `:unwrap` | Quantity to a number (`remove_unit`). |

The evaluator converts later quantity arguments into the first **quantity**
argument's unit for `:additive` functions, and for `:point` functions on
**additive** categories. Static analysis uses the same rule for any
function — including custom ones — so `if(false, coalesce(1m, 2m), 100cm)`
and `if(false, double(1m), 100cm)` both return metres. Short-circuit
functions (`if`, `coalesce`) may implement `evaluate_call/2`; catalog-aware
functions (`convert`, `add_unit`) may implement `call/2`.

`convert/2`, `add_unit/2`, and `remove_unit/1` declare `:convert`, `:wrap`,
and `:unwrap`. Custom functions that omit `units:` are `:additive` — an
unmarked `double(1C)` errors; `double(1m)` works. To preserve any quantity
including `C`, set `units: :point` (`2 * 1C` stays illegal as a language
op).

Use `Elex.Validator.same_numeric_type/2` when every argument must be the same
numeric type (`:decimal` or one category). It returns `{:ok, type}`,
`{:mismatch, type}` when the first argument is not numeric,
`{:mismatch, expected, got}` when later arguments differ, or `{:error, reason}`.
Use `Elex.Validator.numeric_mismatch_message/2` for the built-in wording
(`cannot mix length and mass` vs `expects number arguments, got string`).
Non-additive `:point` functions also require `Elex.Unit.same?/2` (the validator
enforces this).

Pick one of three patterns.

### Reject unitful arguments

`sqrt`-style: only numbers (no units). Set `units: :none`, check
`{:ok, :decimal}`, and leave `call/1` matching on `Decimal`. String
functions use the same `units: :none` policy:

```elixir
def signature, do: %{name: :sqrt, arity: 1, units: :none}

def validate([arg], ctx) do
  case Elex.Validator.validate(arg, ctx) do
    {:ok, :decimal} -> {:ok, :decimal}
    {:ok, type} -> {:error, "sqrt expects a number, got #{inspect(type)}"}
    {:error, reason} -> {:error, reason}
  end
end

def call([arg]) when is_struct(arg, Decimal) do
  {:ok, Decimal.sqrt(arg)}
end
```

### Preserve the unit

`abs`-style: accept a number or a quantity of one category. Set
`units: :point` so same-unit non-additive quantities (`1C`) are allowed.
Validate with `same_numeric_type/2`, unwrap the quantity in `call/1`, then
rewrap the same unit. Omitted `units:` is `:additive` and rejects `1C`.

```elixir
def signature, do: %{name: :abs, arity: 1, units: :point}

def validate([arg], ctx) do
  case Elex.Validator.same_numeric_type([arg], ctx) do
    {:ok, type} -> {:ok, type}
    {:mismatch, type} -> {:error, "abs expects a number, got #{inspect(type)}"}
    {:error, reason} -> {:error, reason}
  end
end

def call([%Elex.Quantity{value: value, unit: unit}]) do
  {:ok, result} = call([value])
  {:ok, %Elex.Quantity{value: result, unit: unit}}
end

def call([arg]) when is_struct(arg, Decimal) do
  {:ok, Decimal.abs(arg)}
end
```

### Same-category multi-arg

`min` / `between`-style: `units: :point` and `same_numeric_type/2` so every
argument is `:decimal` or the same category. On additive categories, later
quantity arguments are already converted into the first quantity argument's unit, so
`call/1` can compare or combine `.value` fields and rewrap the first unit
(or return a boolean). On non-additive categories the units must already
match (`min(1C, 2C)` works; `min(1C, 32F)` errors):

```elixir
def signature, do: %{name: :min, variadic: true, min_arity: 2, units: :point}

def validate(args_ast, ctx) do
  case Elex.Validator.same_numeric_type(args_ast, ctx) do
    {:ok, type} -> {:ok, type}
    {:error, reason} -> {:error, reason}
    mismatch -> {:error, Elex.Validator.numeric_mismatch_message("min", mismatch)}
  end
end

def call([%Elex.Quantity{unit: unit} | _] = args) do
  {:ok, result} = call(Enum.map(args, & &1.value))
  {:ok, %Elex.Quantity{value: result, unit: unit}}
end

def call([first | rest]) do
  {:ok, Enum.reduce(rest, first, &Decimal.min/2)}
end
```

The optional `:category` atom (e.g. `:math`, `:string`, `:utility`) is included in
`Elex.Context.list_functions/1` output so host applications can group functions in
documentation UIs.

Register the function on a context:

```elixir
context =
  Elex.new_context()
  |> Elex.Context.add_function(MyApp.Functions.Double)

{:ok, result} = Elex.evaluate("double(5)", context)
# => #Decimal<10>
```

The `Elex.Function` Double example omits `units:`, so it is `:additive`.
`double(1m)` works; `double(1C)` errors. Language ops still reject
`2 * 1C`. Setting `units: :point` would allow `double(1C)` because
`double` is a function, not `*`.

### Variadic functions

Return a variadic signature with `min_arity`:

```elixir
def signature do
  %{name: :sum, variadic: true, min_arity: 2}
end
```

The context stores variadic functions under `{name, :variadic}`.

## Localizing type error labels

`Elex.Labels.label/1` maps type atoms and `%Elex.Dimension{}` structs to
human-readable names used in error messages (`:decimal` → `"number"`,
`%Elex.Dimension{monomial: %{length: 1}}` → `"length"`). Override this
function in your application to integrate with Gettext for localization.

## Further reading

- `Elex.Parser` — parse options including `:max_depth`
- `Elex.Validator` — direct AST validation
- `Elex.Evaluator` — direct AST evaluation
- `Elex.Function` — behaviour reference
- [Functions](functions.md) — built-in function list
