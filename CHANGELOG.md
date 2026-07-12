# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/bandesz/elex/releases/tag/v0.1.0
