# Autocomplete user flows

Canonical behaviour for [expression autocomplete](index.md). Actor is always a **library caller** (host UI). `|` marks the cursor. Ranges are exclusive-end UTF-8 byte offsets.

Unless a flow says otherwise, the fixture context is `Elex.new_context()` plus:

- variable `foo` (decimal `1`)
- variable `mass` (decimal `2`)
- standard functions
- no units catalog

Length catalog flows register `:length` with units `m` and `mm` (and attach the catalog).

## Flow 1: Incomplete variable

**Precondition:** default fixture (`foo` present)

**Steps:**

1. `autocomplete("1 + (2 * f", 10, ctx)` → `range: {9, 10}`; suggestions include `%{kind: :variable, text: "foo"}`. No other **variables** unless they also start with `f`. Functions and keywords matching `f` (`false`, `floor`) are also present.

**Error paths:**

- Prefix `z` with no matching names → `{:ok, %{…, suggestions: []}}` (not an error)

## Flow 2: Empty operand (default)

**Precondition:** default fixture

**Steps:**

1. `autocomplete("1 + ", 4, ctx)` → `{:ok, %{range: {4, 4}, suggestions: []}}`
2. Same on `""` with cursor `0` → `{:ok, %{range: {0, 0}, suggestions: []}}`

**Error paths:** none (empty list is success)

## Flow 2b: Empty operand (opt-in dump)

**Precondition:** default fixture

**Steps:**

1. `autocomplete("1 + ", 4, ctx, empty_prefix: :all)` → `suggestions` contains:
   - variables `foo`, `mass`
   - every registered function name (`abs`, `max`, …) as `:function` with `:signature` and `:description`
   - keywords `true`, `false`, `yes`, `no`, `null`, `not`
2. Does **not** contain units or infix `and` / `or`

## Flow 3: Glued unit suffix

**Precondition:** length catalog (`m`, `mm`); variable `mass` still on the context

**Steps:**

1. `autocomplete("10m", 3, ctx)` → `range: {2, 3}`; suggestions `%{kind: :unit, text: "m"}` and `%{kind: :unit, text: "mm"}`
2. `mass` is **not** suggested (`10mass` is a suffix, not juxtaposition of a variable)

**Error paths:**

- No catalog (Flow 11)

## Flow 4: Empty after a number

**Precondition:** length catalog for unit bullets; default fixture otherwise

**Steps:**

1. `autocomplete("10 ", 3, ctx)` with default opts → `range: {3, 3}`, `suggestions: []`
2. `empty_prefix: :all` with catalog → units `m`, `mm` **and** keywords `and`, `or`
3. `empty_prefix: :all` on glued `"10"` cursor `2` → units only; **not** `and` / `or` (`10and` is not the `and` operator)
4. `empty_prefix: :all` on `"10 "` with **no** catalog → `and`, `or` only

## Flow 5: Function name

**Precondition:** default fixture (`mass` present)

**Steps:**

1. `autocomplete("1 + ma", 6, ctx)` → `range: {4, 6}`
2. Suggestions include `%{kind: :function, text: "max", …}`, `%{kind: :function, text: "match", …}`, `%{kind: :variable, text: "mass"}`
3. Function `:text` is the name only (`"max"`, not `"max("`)

## Flow 6: Operand keywords

**Precondition:** default fixture

**Steps:**

1. `autocomplete("n", 1, ctx)` → `range: {0, 1}`
2. Suggestions include keywords `not`, `null`, `no` (and any variable/function whose name starts with `n`)

## Flow 7: Infix keywords

**Precondition:** default fixture

**Steps:**

1. `autocomplete("true a", 6, ctx)` → `range: {5, 6}`
2. Suggestions include `%{kind: :keyword, text: "and"}`
3. Does **not** include `abs` (juxtaposition `true abs` is invalid)

## Flow 8: Unit string argument

**Precondition:** length catalog (`m`, `mm`)

**Steps:**

1. `autocomplete("convert(1m, \"m", 14, ctx)` → `range: {13, 14}`; unit suggestions matching `m`
2. Same slot for `add_unit(1, \"m|` and for a custom function whose `signature/0` has `units: :convert` or `units: :wrap`, when the cursor is inside that call’s **second** argument string (including an unclosed `"`)
3. `empty_prefix: :none` on `convert(1m, "|` (cursor after the opening quote) → `[]`
4. `empty_prefix: :all` on that empty string interior → all catalog names and aliases

**Error paths:**

- Cursor inside a string that is **not** that argument (Flow 10)

## Flow 9: Cursor in the middle of a token

**Precondition:** default fixture; variables `foo` and (optionally) nothing named `foobar`

**Steps:**

1. Expression `"1 + foobar"`, cursor `6` (`fo|obar`) → `range: {4, 10}` (whole `foobar`)
2. Prefix used for matching is `"fo"`; `foo` is suggested when it starts with `fo`
3. Applying `text: "foo"` replaces bytes `[4, 10)` so the host does not leave `obar`

## Flow 10: Normal string

**Precondition:** default fixture

**Steps:**

1. `autocomplete("concat(\"hel", 11, ctx)` → `suggestions: []`

## Flow 11: No catalog

**Precondition:** default fixture, `units` is `nil`

**Steps:**

1. `autocomplete("10m", 3, ctx)` → `range: {2, 3}`, `suggestions: []` (glued suffix is not an operand identifier)

## Flow 12: Invalid cursor

**Precondition:** any context

**Steps:**

1. Cursor `99` on `"1 + 2"` → `{:error, "cursor is out of range"}`
2. Cursor `-1` → `{:error, "cursor is out of range"}`
3. Cursor in the middle of a multi-byte UTF-8 codepoint → `{:error, "cursor is out of range"}`

**Error paths:** these **are** the error path; they are not `{:ok, []}`
