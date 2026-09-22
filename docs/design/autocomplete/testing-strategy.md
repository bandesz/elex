# Autocomplete testing strategy

Library-only ExUnit and unit TDD (`test-driven-development`). No UI flow tests — there is no UI in this repo. Hosts consume `Elex.autocomplete/4`.

Canonical behaviour: [user-flows.md](user-flows.md).

**File:** `test/elex/autocomplete_test.exs` for all flows.

**Fixtures:** `Elex.new_context()` plus `foo` / `mass` decimals; length catalog `m` / `mm` only in unit flows. Reuse catalog helpers already used in `test/elex/units/*` rather than inventing a second catalog shape.

| Flow | Proves |
|---|---|
| 1 | Incomplete `1 + (2 * f` → `false` (`:keyword`), `floor` (`:function`), `foo` (`:variable`), range `{9, 10}`; unknown prefix → `[]` |
| 2 | Empty operand default `[]`; empty expression cursor `0` → `[]` |
| 2b | `empty_prefix: :all` dumps variables, functions, operand keywords; not units or `and`/`or` |
| 3 | Glued `10m` → `m`/`mm`; not variable `mass` |
| 4 | Empty after number default `[]`; `:all` spaced → units + `and`/`or`; glued `:all` → units only; no catalog `:all` → `and`/`or` only |
| 5 | `1 + ma` → `max`/`match` as functions (name only) and `mass` |
| 6 | `n` → `not`/`null`/`no` |
| 7 | `true a` → `and`, not `abs` |
| 8 | `convert(1m, "m` range `{13, 14}`; `add_unit` / custom `:wrap`/`:convert`; empty string interior respects `empty_prefix` |
| 9 | Cursor `6` in `1 + foobar` → range `{4, 10}`, prefix `fo` |
| 10 | `concat("hel` → `[]` |
| 11 | `10m` without catalog → `[]` |
| 12 | cursor `99`, `-1`, mid-codepoint → `{:error, "cursor is out of range"}` |

Also: unknown opts and bad `empty_prefix` raise `ArgumentError` (Task 1.1).

Guides: `guides/getting-started.md` and/or `guides/advanced.md`, `README.md`, `CHANGELOG.md` Unreleased (Task 1.4).

## Coverage checklist

Check items off in **implementing-design Phase 4** (not a separate batch task).

- [x] Flow 1 incomplete variable and unknown-prefix `[]`
- [x] Flow 2 default empty prefix `[]`
- [x] Flow 2b `empty_prefix: :all` operand dump
- [x] Flow 3 glued units exclude variables
- [x] Flow 4 empty after number (default, spaced `:all`, glued `:all`, no catalog)
- [x] Flow 5 functions name-only + overlapping variable
- [x] Flow 6 operand keywords
- [x] Flow 7 infix `and` excludes functions
- [x] Flow 8 convert/add_unit/custom wrap string
- [x] Flow 9 mid-token whole-token range
- [x] Flow 10 normal string `[]`
- [x] Flow 11 no catalog `[]`
- [x] Flow 12 out-of-range cursor
- [x] `ArgumentError` on unknown opts / bad `empty_prefix`
