# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Elex is an expression language library for Elixir that provides parsing, validation, and evaluation of mathematical and logical expressions. It supports arithmetic operations, comparisons, logical operations, variables, functions, static type checking, and expression inversion.

## Development Commands

### Setup
```bash
mix deps.get        # Install dependencies
```

### Testing
```bash
mix test                                 # Run all tests
mix test test/path/to/test.exs           # Run a single test file
mix test test/path/to/test.exs:42        # Run a specific test at line 42
mix test.ci                              # Run tests with coverage and warnings as errors (used in CI)
```

### Code Quality
```bash
mix check           # Run all quality checks (compile, format check, credo, sobelow, deps audit)
mix format          # Format code
mix credo --strict  # Run Credo linter in strict mode
mix dialyzer        # Run Dialyzer type checker
mix sobelow         # Run Sobelow security analysis
mix precommit       # Run all pre-commit checks (compile, format, credo, sobelow, deps audit, tests)
```

### Git Hooks
Enable pre-commit hook for automatic quality checks:
```bash
git config core.hooksPath .git-hooks
```

### Documentation
```bash
mix docs            # Generate documentation
```

## Architecture

### Core Components

The library follows a pipeline architecture: **Parse → Validate → Evaluate**

1. **Parser** (`Elex.Parser`): Uses NimbleParsec to convert expression strings into an Abstract Syntax Tree (AST). Supports literals (decimal, boolean, string), variables, operators (arithmetic, comparison, logical), and function calls.

2. **Validator** (`Elex.Validator`): Performs static type checking on the AST before evaluation. Ensures type compatibility for operations and functions.

3. **Evaluator** (`Elex.Evaluator`): Walks the AST and computes the result. Uses `Decimal` library for precise arithmetic. Evaluates expressions within a `Context`.

4. **Context** (`Elex.Context`): Holds the execution environment containing variables and available functions. Variables are stored as `Elex.Variable` structs with type information.

5. **Inverter** (`Elex.Inverter`): Inverts simple single-variable arithmetic expressions. Transforms expressions like `value * 2 + 5` into the inverse form that solves for the variable.

### Function System

Functions implement the `Elex.Function` behavior with three callbacks:
- `signature/0`: Returns function name and arity
- `validate/2`: Type-checks arguments and returns result type
- `call/1`: Executes the function with evaluated arguments

Built-in functions are in `lib/elex/functions/` and automatically registered in the standard context.

### AST Structure

The AST uses tagged tuples:
- Literals: `%Decimal{}`, `true/false`, `"string"`
- Variables: `{:var, "variable_name"}`
- Binary operations: `{operator, [left_ast, right_ast]}`
- Unary operations: `{:not, operand_ast}`
- Functions: `{:func, "name", arity, [arg_asts]}`

### Type System

Three core types: `:decimal`, `:boolean`, `:string`
- Type checking happens during parsing/validation
- Type errors are caught before evaluation
- Variables must have types assigned in the context

## Code Style

- **Line length**: Max 120 characters
- **Formatting**: Uses `mix format` with Ash imports configured in `.formatter.exs`
- **Linting**: Credo in strict mode with custom configuration in `.credo.exs`
- **Module docs**: Not required (disabled in Credo config)
- **Negated conditions**: Allowed when clearer than positive conditions
- **Refactoring checks**: Set to informational only (won't fail builds)

## Testing Conventions

- Test files mirror lib structure: `test/elex/` matches `lib/elex/`
- Function tests are in: `test/elex/expression/functions/`
- Use ExUnit for all tests
- Test files use `.exs` extension
- Comprehensive test coverage with 80% threshold

## Ash Integration

Optional Ash validation available via `Elex.AshValidation` for validating expressions in Ash resource attributes. The `:ash` dependency is optional.
