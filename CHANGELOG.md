# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2026-08-02

### Added

- `match(text, pattern)` string function for regex matching
- String literal escapes: `\"`, `\\`, `\n`, `\t`, `\r`, `\f`, `\b`

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

[0.2.2]: https://github.com/bandesz/elex/releases/tag/v0.2.2
[0.2.1]: https://github.com/bandesz/elex/releases/tag/v0.2.1
[0.2.0]: https://github.com/bandesz/elex/releases/tag/v0.2.0
[0.1.0]: https://github.com/bandesz/elex/releases/tag/v0.1.0
