# Advanced Topics

This guide covers lower-level APIs for applications that need direct access to
the parse tree, expression inversion, or custom functions.

## The parse → validate → evaluate pipeline

Most callers use `Elex.evaluate/2`, which runs all three stages. For more
control, use the modules directly:

```elixir
context = Elex.new_context() |> Elex.add_variable("x", 10)

{:ok, ast, type} = Elex.Parser.parse("x + 5", context)
# type => :decimal

Elex.Evaluator.evaluate(ast, context)
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

> **Note:** `Elex.Evaluator.evaluate/2` raises `RuntimeError` on failures.
> `Elex.evaluate/2` catches these and returns `{:error, reason}`. Prefer the
> high-level API unless you handle exceptions yourself.

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

context = Elex.new_context() |> Elex.add_variable("value", 0)

{:ok, ast, _} = Parser.parse("value * 2 + 5", context, validate: false)
{:ok, inverted} = Inverter.invert(ast, "value")

# Evaluate inverted AST with a known result to recover the original variable:
result_context = Elex.new_context() |> Elex.add_variable("value", 21)
Elex.Evaluator.evaluate(inverted, result_context)
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
| `documentation/0` | Human-readable signature and description |

### Example

```elixir
defmodule MyApp.Functions.Double do
  @behaviour Elex.Function

  @impl true
  def signature, do: %{name: :double, arity: 1}

  @impl true
  def validate([arg], ctx) do
    case Elex.Validator.validate(arg, ctx) do
      {:ok, :decimal} -> {:ok, :decimal}
      {:ok, type} -> {:error, "double expects a number, got #{inspect(type)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def call([arg]), do: {:ok, Decimal.mult(arg, Decimal.new(2))}

  @impl true
  def documentation do
    %{signature: "double(x)", description: "returns x multiplied by 2"}
  end
end
```

Register the function on a context:

```elixir
context =
  Elex.new_context()
  |> Elex.Context.add_function(MyApp.Functions.Double)

{:ok, result} = Elex.evaluate("double(5)", context)
# => #Decimal<10>
```

### Variadic functions

Return a variadic signature with `min_arity`:

```elixir
def signature do
  %{name: :sum, variadic: true, min_arity: 2}
end
```

The context stores variadic functions under `{name, :variadic}`.

## Localizing type error labels

`Elex.Labels.label/1` maps type atoms to human-readable names used in error
messages (`:decimal` → `"number"`, etc.). Override this function in your
application to integrate with Gettext for localization.

## Further reading

- `Elex.Parser` — parse options including `:max_depth`
- `Elex.Validator` — direct AST validation
- `Elex.Evaluator` — direct AST evaluation
- `Elex.Function` — behaviour reference
- [Functions](functions.md) — built-in function list
