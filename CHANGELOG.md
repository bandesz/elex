# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Literal unitless `0` (`0`, `0.0`, `-0`) next to an additive quantity in
  comparisons and `:point` functions (`10cm > 0`, `clamp(width, 0, 10cm)`,
  `if(width > 0, width, 0)`). `10cm + 0` and non-additive `1C > 0` stay errors

## [0.3.0] - 2026-09-02

### Added

- Opt-in unit catalogs via `Elex.Units.Catalog` and `Elex.Context.put_units/2`
  (`put_units!/2`). Elex does not ship units; callers register categories,
  conversions, aliases, and derived formulas
- Quantity results: `%Elex.Quantity{value, unit: %Elex.Unit{}}`. Validate
  returns `%Elex.Dimension{}` for unitful types
- Literal suffixes on numeric literals: registered name or alias (`10mm`),
  power (`5m^2`), unbraced pipe (`3 m|s`), braced formula (`1 {kg * m | s}`)
- Scientific notation (`1e3`, `1.5E-2`); `e` and `E` cannot be unit names
- Conversion: `evaluate(..., unit: …)`, `validate`/`evaluate` `category: …`,
  and expression `convert/2`, `add_unit/2`, `remove_unit/1`
- Derived categories (`formula:`, hub `default:`, optional `identity:` that
  names the base-hub formula; a matching identity unit is still required);
  `aliases:` on `add_unit`; `Catalog.add_unit/3` omits conversion (`"value"`);
  `Catalog.kind/2`
- Non-additive categories (`additive: false`) for temperature-style points
- Function `units:` policies (`:point | :additive | :none | :convert | :wrap | :unwrap`);
  optional `call/2` and `evaluate_call/2` on `Elex.Function`
- Bang helpers: `add_variable!/3`, `add_variables!/2`, `put_units!/2`,
  `Unit.new!/1`, `Evaluator.evaluate!/2`
- Ash `:expected_type` may be a catalog category when a catalog is attached
- Helpers: `Validator.same_numeric_type/2`, `Unit.convertible?/3`,
  `Unit.compatible?/3`, `Unit.from_monomial/1`

### Changed

- `Elex.extract_variables/2` requires a context so unit suffixes parse when
  a catalog is attached (was `extract_variables/1`)
- `Elex.add_variable/3` and `Elex.add_variables/2` always return
  `{:ok, context} | {:error, reason}` (use the bang variants to pipe)
- `Elex.Evaluator.evaluate/2` returns `{:ok, result} | {:error, reason}`
  (use `evaluate!/2` to raise; previously raised `RuntimeError`)
- `Elex.evaluate/2` no longer prefixes evaluation failures with
  `Evaluation error:`; callers receive the same reason strings as
  parse/validate (`division by zero`)
- Function evaluation errors with a string reason are no longer wrapped in
  `Error calling function name/arity: …`
- Without a units catalog, glued suffixes are unexpected tokens
  (`width + 2mm` → `unexpected 'mm'`), not a missing operand

## [0.2.3] - 2026-08-15

### Changed

- `concat` is now variadic and accepts zero or more string arguments
  (`concat()` returns `""`; `concat("a")` returns `"a"`)

## [0.2.2] - 2026-08-02

### Added

- `match(text, pattern)` string function for regex matching
- String literal escapes: `\"`, `\\`, `\n`, `\t`, `\r`, `\f`, `\b`
- `Elex.Context.list_functions/1` to list registered functions with metadata
  (`:module`, `:name`, `:arity`, `:signature`, `:description`, and optional
  `:category`)
- `Elex.list_standard_function_modules/0` to distinguish built-in functions from
  custom ones
- Optional `:category` atom in the `documentation/0` callback on `Elex.Function`
  (set on all built-in functions as `:math` or `:string`)

### Changed

- Unknown string escape sequences now report `invalid escape sequence '\X'` instead
  of a generic missing closing quote

## [0.2.1] - 2026-07-12

### Changed

- Relaxed `decimal` dependency to `~> 2.0 or ~> 3.0`

## [0.2.0] - 2026-07-12

### Added

- Unary minus operator (`-x`, `-(1 + 2)`)
- Modulo operator (`%`) with `*`-level precedence
- `null` literal with equality comparisons to `null` and nil variables
- String ordering comparisons (`<`, `>`, `<=`, `>=`) for string operands
- Short-circuit evaluation for `and`, `or`, and `if(condition, a, b)`
- Math functions: `abs`, `pow`, `mod`, `clamp`, `between`
- Variadic `min` and `max` (two or more arguments)
- String functions: `concat`, `length`, `contains`, `starts_with`, `ends_with`, `lower`, `upper`, `trim`
- `coalesce` function (variadic; returns the first non-null argument)
- Hexdocs guides: Getting Started, Expression Language, Functions, Ash Integration, and Advanced Topics

### Changed

- `mod(a, b)` now uses floored modulo (sign follows the divisor), distinct from `rem(a, b)` and `%`
- `between(x, low, high)` returns an error when `low > high`, matching `clamp/3`

## [0.1.0] - 2025-07-12

### Changed

- `Elex.evaluate/2` returns `{:error, reason}` for all evaluation failures, including division by zero
- `Elex.Inverter.invert/2` returns `{:ok, ast}` or `{:error, reason}` instead of raising
- Updated `decimal` dependency to `~> 3.1` and `ash` to `~> 3.22`

### Added

- Expression parsing, type validation, and evaluation with `Decimal` arithmetic
- Arithmetic, comparison, and logical operators
- Built-in functions: `ceil`, `floor`, `if`, `max`, `min`, `pi`, `rem`, `round`, `sqrt`
- Variable substitution and variable extraction from expressions
- Expression inversion for simple single-variable arithmetic
- Optional Ash resource validation via `Elex.AshValidation`
- `Elex.Function` behaviour for custom functions

[0.3.0]: https://github.com/bandesz/elex/releases/tag/v0.3.0
[0.2.3]: https://github.com/bandesz/elex/releases/tag/v0.2.3
[0.2.2]: https://github.com/bandesz/elex/releases/tag/v0.2.2
[0.2.1]: https://github.com/bandesz/elex/releases/tag/v0.2.1
[0.2.0]: https://github.com/bandesz/elex/releases/tag/v0.2.0
[0.1.0]: https://github.com/bandesz/elex/releases/tag/v0.1.0
