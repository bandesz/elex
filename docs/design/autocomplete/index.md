# Expression autocomplete

Library API so host UIs can complete identifiers in Elex input fields. Works on **incomplete** input (`1 + (2 * f` still completes `foo`). Suggestions are **syntactic** (legal in this slot), not type-checked.

**Status:** complete

## Start here

| Doc | What it contains |
|---|---|
| [user-flows.md](user-flows.md) | Canonical behaviour — numbered caller journeys |
| [architecture.md](architecture.md) | Scanner, slots, data flow, errors |
| [testing-strategy.md](testing-strategy.md) | ExUnit mapping from flows to tests |

## Problem and constraints

Hosts need completions while the user is still typing. `Elex.Parser.parse/3` is all-or-nothing, so `1 + (2 * f` cannot be completed by re-parsing. The method must return a **replacement range** (the token under the cursor) plus suggestions that are valid **in that slot** (operand vs unit suffix vs `convert`/`add_unit` string vs infix `and`/`or`).

**Constraints:**

- New callable surface on `Elex`; context already holds variables, functions, and an optional catalog
- Cursor is a 0-based UTF-8 **byte** offset (same as parser `:byte_offset`)
- No type filtering and no `expected_type:` in v1
- No UI in this repo — hosts consume the Elixir API
- Empty prefix dumps nothing by default (`1 + |` → `[]`)

## Decisions

1. **Architecture:** dedicated scanner + slot classifier. Not NimbleParsec recovery, not splice-and-reparse (trailing `and` still would not parse).
2. **Kinds in v1:** variables, units, function names, keywords (`true`/`false`/`yes`/`no`/`null`/`not`/`and`/`or`).
3. **Insert text:** the token only. Functions do not insert `(`. Hosts may add parentheses from `kind: :function`.
4. **Units:** numeric suffixes (`10m`, `10 m`) and the 2nd-argument **string** of any registered function with `units: :convert | :wrap`. Not formula interiors (`{kg * …}`).
5. **Empty prefix:** option `empty_prefix: :none | :all`, default `:none`. Applies to every slot, not only operands.
6. **Replacement:** whole token; filter by prefix `[start, cursor)`. Mid-token `fo|obar` replaces `foobar`.
7. **Type filtering / `expected_type:`:** deferred (chosen then reverted for v1).

## Assumptions

- Prefix match is case-sensitive `String.starts_with?/2`.
- Suggestions sort by `:text` (Elixir byte order). Kinds are interleaved.
- One function suggestion per name; if several arities exist, keep the first entry from `Context.list_functions/1` (already name-sorted, then registration order for the same name).
- Function maps include `:signature` and `:description`; optional `:category` when `documentation/0` has it.
- Variable and keyword maps are `%{kind: …, text: …}` only (no types).
- Unit suggestions are registered **canonical names and aliases**; insert the spelling that matched. No synthesized `m^2` / pipe formulas unless that string is registered.
- `yes` / `no` are keywords alongside `true` / `false`.
- `and` / `or` require whitespace on both sides (parser `ws_req`); glued `10and` is not infix.
- Unit-string slot uses `Elex.Function.units/1` in `[:convert, :wrap]`, not only the two built-in names.
- Range is always `{start, end}` exclusive end, even when `suggestions` is `[]`.
- Cursor must be an integer on a UTF-8 boundary in `0..byte_size(expression)`; otherwise `{:error, "cursor is out of range"}`.
- Invalid `empty_prefix` or unknown opts raise `ArgumentError` (same pattern as `evaluate/3`).
- Incomplete numbers (`10.`, `10e+`) are slot `:none` (no units until the number token is complete). `10e` / `10eV` is a unit-suffix prefix `e` (scientific exponent needs a digit).
- Coverage checklist updates are **implementing-design Phase 4**.

## Non-goals

- Type-aware filtering and `expected_type:`
- Formula-interior completions (`1 {kg * |`)
- Inserting `(` or signature snippets
- Completing operators `+ − * / % < > ==` and friends
- Phoenix/LiveView UI in this repository
- Ranking by usage or fuzzy / substring match

## Public surface

**Added:** `Elex.autocomplete/4` (and `/3` with default opts). Compatibility: **new**. Who can call: any library caller.

```elixir
@spec autocomplete(String.t(), integer(), Context.t()) ::
        {:ok, result} | {:error, String.t()}
@spec autocomplete(String.t(), integer(), Context.t(), keyword()) ::
        {:ok, result} | {:error, String.t()}
```

- **Inputs:** expression, cursor byte offset, context, opts
- **Opts:** `empty_prefix: :none` (default) | `:all`
- **Result:** `%{range: {start, end}, suggestions: [suggestion]}`
- **suggestion:**
  - `%{kind: :variable, text: String.t()}`
  - `%{kind: :unit, text: String.t()}`
  - `%{kind: :keyword, text: String.t()}`
  - `%{kind: :function, text: String.t(), signature: String.t(), description: String.t()}` plus optional `:category`

**Valid:** context has `foo`; `autocomplete("1 + (2 * f", 10, ctx)` → `range: {9, 10}`; suggestions include `%{kind: :keyword, text: "false"}`, `%{kind: :function, text: "floor", ...}`, and `%{kind: :variable, text: "foo"}` (sorted by text).

**Invalid:** `autocomplete("1 + 2", 99, ctx)` → `{:error, "cursor is out of range"}`

## Architecture

See [architecture.md](architecture.md). Public function in `lib/elex.ex` delegates to `Elex.Autocomplete`. Scanner classifies a slot, then prefix-filters candidates from the context and catalog.

## Testing strategy

See [testing-strategy.md](testing-strategy.md). Library ExUnit and `test-driven-development`. No UI flow tests. Single file `test/elex/autocomplete_test.exs`.

## Batch 1: Autocomplete API
**Status:** done

**Scope:** `Elex.autocomplete/4`, scanner, all four kinds, hexdocs. Excludes: type filtering, formula interiors, UI.

### Task 1.1: API, range, empty prefix, variable operands
**Status:** done — `fd7e345`

- Files: Create `lib/elex/autocomplete.ex`, `test/elex/autocomplete_test.exs`; Modify `lib/elex.ex`, `mix.exs` (`groups_for_modules`)
- TDD: yes
- UI flow: N/A
- Verify: `mix test test/elex/autocomplete_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 1 (variables-only checkpoint for this task; functions and keywords were out of scope): `autocomplete("1 + (2 * f", 10, ctx)` → `range: {9, 10}` and suggestions include `%{kind: :variable, text: "foo"}`. Canonical full result (also `false`, `floor`) is in [Public surface](#public-surface) above and [user-flows.md](user-flows.md) Flow 1 — not what commit `fd7e345` asserted alone
  - Flow 2: `autocomplete("1 + ", 4, ctx)` → `suggestions: []`; with `empty_prefix: :all` the list includes `foo` and does not include units
  - Flow 9: `autocomplete("1 + foobar", 6, ctx)` → `range: {4, 10}`; prefix `fo`; picking `foo` is the `foo` suggestion
  - Flow 12: cursor `99` or `-1` or a mid-codepoint offset → `{:error, "cursor is out of range"}`
  - Unknown option or `empty_prefix: :bogus` raises `ArgumentError`
- Out of scope: function/keyword/unit suggestions (Tasks 1.2–1.3)

### Task 1.2: Functions and keywords
**Status:** done — `9679542` (+ review fixes: `c784135`)

- Files: Modify `lib/elex/autocomplete.ex`; Test `test/elex/autocomplete_test.exs`
- TDD: yes
- UI flow: N/A
- Verify: `mix test test/elex/autocomplete_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 5: `1 + ma|` includes `max` and `match` as `:function` with `:signature` and `:description`, insert text `max` / `match` (no `(`), and variable `mass` if present
  - Flow 6: `n|` includes keywords `not`, `null`, `no`
  - Flow 7: `true a|` includes `and` and does not include `abs`
  - Flow 2b: `empty_prefix: :all` on `1 + |` includes functions and operand keywords (`true`, `not`, …) as well as variables
  - Flow 4 infix: `empty_prefix: :all` on `10 |` includes `and` and `or`; glued `10|` with `:all` does not
- Out of scope: unit suffixes and convert/add_unit strings (Task 1.3)

### Task 1.3: Units and convert/add_unit strings
**Status:** done — `a135f94` (+ review fixes: `c5ee82d`, `cbe4839`)

- Files: Modify `lib/elex/autocomplete.ex`; Test `test/elex/autocomplete_test.exs`
- TDD: yes
- UI flow: N/A
- Verify: `mix test test/elex/autocomplete_test.exs`
- Domain skills: `test-driven-development`
- Acceptance:
  - Flow 3: `10m|` with catalog `m`/`mm` and variable `mass` → units `m`, `mm`; not `mass`
  - Flow 4 units: `10 |` default `[]`; `empty_prefix: :all` includes `m` and `mm`
  - Flow 8: `convert(1m, "m|` → range `{13, 14}`; units matching `m`. Same slot for `add_unit` and any `units: :convert | :wrap` function
  - Flow 10: `concat("hel|` → `suggestions: []`
  - Flow 11: `10m|` with no catalog → `suggestions: []`
- Out of scope: formula interiors; type filtering

### Task 1.4: Guides and changelog
**Status:** done — `573d907`

- Files: Modify `guides/getting-started.md`, `guides/advanced.md`, `README.md`, `CHANGELOG.md`, `lib/elex.ex` (`@moduledoc` feature list)
- TDD: no
- UI flow: N/A
- Verify: `mix test test/elex/autocomplete_test.exs`
- Acceptance:
  - Getting Started (or Advanced) documents `Elex.autocomplete/4`, cursor bytes, `empty_prefix: :none | :all`, and the Flow 1 example
  - README feature list mentions autocomplete
  - Unreleased changelog records the new API
- Out of scope: code behaviour (Tasks 1.1–1.3)
